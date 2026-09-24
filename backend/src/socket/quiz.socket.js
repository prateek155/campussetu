// backend/src/socket/quiz.socket.js
// High-performance native WebSocket server for live quizzes
const { WebSocketServer, WebSocket } = require('ws');
const db = require('../config/db');
const admin = require('../config/firebase');
const { submitQuizAnswer } = require('../services/quizAnswer.service');

// In-memory quiz sessions
// Map<quizId, { status, currentQuestion, totalQuestions, timer, timeLeft, questions: [] }>
const activeQuizzes = new Map();

// Map<quizId, Set<WebSocket>>
const quizRooms = new Map();

function getRoom(quizId) {
  if (!quizRooms.has(quizId)) {
    quizRooms.set(quizId, new Set());
  }
  return quizRooms.get(quizId);
}

function broadcastToRoom(quizId, data, filterFn = null) {
  const room = quizRooms.get(quizId);
  if (!room) return;
  const payload = JSON.stringify(data);
  for (const client of room) {
    if (client.readyState === WebSocket.OPEN) {
      if (!filterFn || filterFn(client)) {
        client.send(payload);
      }
    }
  }
}

function sendToClient(client, data) {
  if (client && client.readyState === WebSocket.OPEN) {
    client.send(JSON.stringify(data));
  }
}

function setupQuizWebSocket(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', async (request, socket, head) => {
    try {
      const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
      const p = url.pathname;
      if (p === '/quiz' || p.startsWith('/quiz') || p === '/api/v1/quiz' || p.startsWith('/api/v1/quiz')) {
        const token = url.searchParams.get('token');
        if (!token) {
          socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
          return socket.destroy();
        }
        const decoded = await admin.auth().verifyIdToken(token, true);
        wss.handleUpgrade(request, socket, head, (ws) => {
          ws.firebaseUid = decoded.uid;
          wss.emit('connection', ws, request);
        });
      }
    } catch (e) {
      console.warn('[Quiz WS Upgrade Error]', e.message);
      if (!socket.destroyed) {
        socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
        socket.destroy();
      }
    }
  });


  wss.on('connection', (ws, req) => {
    console.log('[Quiz WS] New client connected');

    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', async (raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        const { event, quizId } = msg;
        if (!event || !quizId) return;

        // ── 1. FACULTY JOIN ─────────────────────────────────
        if (event === 'faculty-join') {
          if (ws.role) return;
          const { rows: users } = await db.query(
            'SELECT id, role, is_admin FROM users WHERE firebase_uid = $1',
            [ws.firebaseUid]
          );
          const user = users[0];
          if (!user || (user.role !== 'faculty' && user.is_admin !== true)) {
            sendToClient(ws, { event: 'error', message: 'Faculty access required' });
            return ws.close(1008, 'Faculty access required');
          }
          const { rows: quizzes } = await db.query(
            `SELECT id FROM quizzes WHERE id = $1 AND (faculty_id = $2 OR $3 = true)`,
            [quizId, user.id, user.is_admin === true]
          );
          if (!quizzes.length) {
            sendToClient(ws, { event: 'error', message: 'Quiz access denied' });
            return ws.close(1008, 'Quiz access denied');
          }
          ws.quizId = quizId;
          ws.role = 'faculty';
          ws.userId = user.id;
          getRoom(quizId).add(ws);

          const { rows } = await db.query(
            'SELECT COUNT(*)::int AS count FROM quiz_participants WHERE quiz_id = $1',
            [quizId]
          );
          sendToClient(ws, { event: 'participant-count', count: rows[0]?.count || 0 });
          console.log(`[Quiz WS] Faculty joined room: ${quizId}`);
        }

        // ── 2. STUDENT JOIN ─────────────────────────────────
        else if (event === 'student-join') {
          if (ws.role) return;
          const { rows: participants } = await db.query(
            `SELECT p.user_id, u.name
             FROM quiz_participants p
             JOIN users u ON u.id = p.user_id
             JOIN quizzes q ON q.id = p.quiz_id
             WHERE p.quiz_id = $1 AND u.firebase_uid = $2 AND q.status IN ('waiting', 'live')`,
            [quizId, ws.firebaseUid]
          );
          if (!participants.length) {
            sendToClient(ws, { event: 'error', message: 'Join this active quiz first' });
            return ws.close(1008, 'Quiz participation required');
          }
          ws.quizId = quizId;
          ws.role = 'student';
          ws.userId = participants[0].user_id;
          ws.userName = participants[0].name || 'Student';
          getRoom(quizId).add(ws);

          const { rows } = await db.query(
            'SELECT COUNT(*)::int AS count FROM quiz_participants WHERE quiz_id = $1',
            [quizId]
          );
          const count = rows[0]?.count || 0;

          // Notify faculty
          broadcastToRoom(quizId, {
            event: 'participant-count',
            count,
            newStudent: ws.userName,
          }, (c) => c.role === 'faculty');

          // If quiz is already live, send current question to the newly joined student
          const session = activeQuizzes.get(quizId);
          if (session && session.status === 'live' && session.questions) {
            const q = session.questions[session.currentQuestion];
            if (q) {
              const sanitized = {
                id: q.id,
                question_text: q.question_text,
                image_url: q.image_url,
                order_index: q.order_index,
                options: (typeof q.options === 'string' ? JSON.parse(q.options) : q.options)
                  .map(o => ({ text: o.text })),
              };
              sendToClient(ws, {
                event: 'question-start',
                question: sanitized,
                questionIndex: session.currentQuestion,
                totalQuestions: session.questions.length,
                timeLeft: session.timeLeft || 20,
              });
            }
          }
          console.log(`[Quiz WS] Student ${ws.userName} joined room: ${quizId}`);
        }

        // ── 3. FACULTY: GO LIVE ─────────────────────────────
        else if (event === 'go-live') {
          if (ws.role !== 'faculty' || ws.quizId !== quizId) return;

          const { rows: questions } = await db.query(
            'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC, id ASC',
            [quizId]
          );

          if (!questions.length) {
            sendToClient(ws, { event: 'error', message: 'No questions in this quiz' });
            return;
          }

          const { rowCount } = await db.query(
            `UPDATE quizzes SET status = 'live', current_question = 0, question_started_at = NOW()
             WHERE id = $1 AND status = 'waiting'`,
            [quizId]
          );
          if (!rowCount) {
            sendToClient(ws, { event: 'error', message: 'Quiz is not waiting to start' });
            return;
          }

          const session = {
            status: 'live',
            currentQuestion: 0,
            totalQuestions: questions.length,
            timer: null,
            timeLeft: 20,
            questions,
          };
          activeQuizzes.set(quizId, session);

          startQuestionCycle(quizId, 0);
        }

        // ── 4. FACULTY: NEXT QUESTION ───────────────────────
        else if (event === 'next-question') {
          if (ws.role !== 'faculty' || ws.quizId !== quizId) return;
          const session = activeQuizzes.get(quizId);
          if (!session) return;
          if (session.timer) clearInterval(session.timer);

          const nextIndex = session.currentQuestion + 1;
          if (nextIndex >= session.questions.length) {
            await endQuizSession(quizId);
          } else {
            session.currentQuestion = nextIndex;
            session.timeLeft = 20;
            await db.query(
              "UPDATE quizzes SET current_question = $1, question_started_at = NOW() WHERE id = $2 AND status = 'live'",
              [nextIndex, quizId]
            );
            startQuestionCycle(quizId, nextIndex);
          }
        }

        // ── 5. FACULTY: END QUIZ ────────────────────────────
        else if (event === 'end-quiz') {
          if (ws.role !== 'faculty' || ws.quizId !== quizId) return;
          await endQuizSession(quizId);
        }

        // ── 6. STUDENT: SUBMIT ANSWER ───────────────────────
        else if (event === 'submit-answer') {
          if (ws.role !== 'student' || ws.quizId !== quizId) return;
          const { questionId, selectedIndex } = msg;
          const userId = ws.userId;
          if (!userId) return;
          let result;
          try {
            result = await submitQuizAnswer({ quizId, questionId, userId, selectedIndex });
          } catch (err) {
            if (!err.status) console.error('[Quiz WS Answer Error]', err.code || 'unknown error');
            sendToClient(ws, {
              event: 'error',
              message: err.status ? err.message : 'Unable to submit answer',
            });
            return;
          }

          sendToClient(ws, {
            event: 'answer-result',
            isCorrect: result.isCorrect,
            score: result.score,
            correctIndex: result.correctIndex,
            alreadySubmitted: result.alreadySubmitted,
          });
        }
      } catch (err) {
        console.error('[Quiz WS Message Error]', err);
      }
    });

    ws.on('close', async () => {
      if (ws.quizId) {
        const room = quizRooms.get(ws.quizId);
        if (room) {
          room.delete(ws);
          if (room.size === 0) {
            quizRooms.delete(ws.quizId);
          } else if (ws.role === 'student') {
            try {
              const { rows } = await db.query(
                'SELECT COUNT(*)::int AS count FROM quiz_participants WHERE quiz_id = $1',
                [ws.quizId]
              );
              broadcastToRoom(ws.quizId, {
                event: 'participant-count',
                count: rows[0]?.count || 0,
              }, (c) => c.role === 'faculty');
            } catch (_) {}
          }
        }
      }
    });
  });

  // Heartbeat to clean up stale sockets every 30s
  const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (ws.isAlive === false) return ws.terminate();
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000);

  wss.on('close', () => clearInterval(interval));

  console.log('🔌 Native Quiz WebSocket ready on path /quiz');
  return wss;
}

function startQuestionCycle(quizId, index) {
  const session = activeQuizzes.get(quizId);
  if (!session || !session.questions || !session.questions[index]) return;

  const q = session.questions[index];
  session.currentQuestion = index;
  session.timeLeft = 20;

  const rawOptions = typeof q.options === 'string' ? JSON.parse(q.options) : q.options;

  // Sanitized question for students (no correct answer)
  const studentQ = {
    id: q.id,
    question_text: q.question_text,
    image_url: q.image_url,
    order_index: q.order_index,
    options: rawOptions.map(o => ({ text: o.text })),
  };

  // Broadcast to students
  broadcastToRoom(quizId, {
    event: 'question-start',
    question: studentQ,
    questionIndex: index,
    totalQuestions: session.questions.length,
    timeLeft: 20,
  }, (c) => c.role === 'student');

  // Full question to faculty
  broadcastToRoom(quizId, {
    event: 'question-start',
    question: { ...studentQ, options: rawOptions },
    questionIndex: index,
    totalQuestions: session.questions.length,
    timeLeft: 20,
  }, (c) => c.role === 'faculty');

  // 20-second countdown timer
  if (session.timer) clearInterval(session.timer);

  session.timer = setInterval(async () => {
    session.timeLeft--;
    broadcastToRoom(quizId, {
      event: 'time-tick',
      timeLeft: session.timeLeft,
    });

    if (session.timeLeft <= 0) {
      clearInterval(session.timer);
      session.timer = null;

      // Reveal correct answer
      const correctIndex = rawOptions.findIndex(o => o.isCorrect);
      broadcastToRoom(quizId, {
        event: 'question-end',
        correctIndex,
      });

      // Auto-advance to next question after 3 seconds
      setTimeout(async () => {
        const nextIndex = index + 1;
        if (nextIndex >= session.questions.length) {
          await endQuizSession(quizId);
        } else {
          session.currentQuestion = nextIndex;
          try {
            await db.query(
              "UPDATE quizzes SET current_question = $1, question_started_at = NOW() WHERE id = $2 AND status = 'live'",
              [nextIndex, quizId]
            );
          } catch (_) {}
          startQuestionCycle(quizId, nextIndex);
        }
      }, 3000);
    }
  }, 1000);
}

async function endQuizSession(quizId) {
  try {
    const session = activeQuizzes.get(quizId);
    if (session?.timer) clearInterval(session.timer);
    activeQuizzes.delete(quizId);

    await db.query(
      "UPDATE quizzes SET status = 'ended', ended_at = NOW() WHERE id = $1",
      [quizId]
    );

    // Get final leaderboard with names
    const { rows: leaderboard } = await db.query(
      `SELECT p.user_id, p.total_score, u.name
       FROM quiz_participants p JOIN users u ON u.id = p.user_id
       WHERE p.quiz_id = $1
       ORDER BY p.total_score DESC, p.joined_at ASC
       LIMIT 10`,
      [quizId]
    );

    broadcastToRoom(quizId, {
      event: 'quiz-ended',
      leaderboard: leaderboard.map((p, i) => ({ ...p, rank: i + 1 })),
    });

    console.log(`[Quiz WS] Quiz ${quizId} ended successfully`);
  } catch (err) {
    console.error('[Quiz WS] endQuizSession error:', err.message);
  }
}

module.exports = { setupQuizWebSocket };
