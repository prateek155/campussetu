// backend/src/socket/quiz.socket.js
// High-performance native WebSocket server for live quizzes
const { WebSocketServer, WebSocket } = require('ws');
const db = require('../config/db');

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

  server.on('upgrade', (request, socket, head) => {
    try {
      const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
      const p = url.pathname;
      if (p === '/quiz' || p.startsWith('/quiz') || p === '/api/v1/quiz' || p.startsWith('/api/v1/quiz')) {
        wss.handleUpgrade(request, socket, head, (ws) => {
          wss.emit('connection', ws, request);
        });
      }
    } catch (e) {
      console.warn('[Quiz WS Upgrade Error]', e.message);
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
          ws.quizId = quizId;
          ws.role = 'faculty';
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
          ws.quizId = quizId;
          ws.role = 'student';
          ws.userId = msg.userId;
          ws.userName = msg.userName || 'Student';
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
          await db.query(
            "UPDATE quizzes SET status = 'live', current_question = 0 WHERE id = $1",
            [quizId]
          );

          const { rows: questions } = await db.query(
            'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC',
            [quizId]
          );

          if (!questions.length) {
            sendToClient(ws, { event: 'error', message: 'No questions in this quiz' });
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
          const session = activeQuizzes.get(quizId);
          if (!session) return;
          if (session.timer) clearInterval(session.timer);

          const nextIndex = session.currentQuestion + 1;
          if (nextIndex >= session.questions.length) {
            await endQuizSession(quizId);
          } else {
            session.currentQuestion = nextIndex;
            session.timeLeft = 20;
            await db.query('UPDATE quizzes SET current_question = $1 WHERE id = $2', [nextIndex, quizId]);
            startQuestionCycle(quizId, nextIndex);
          }
        }

        // ── 5. FACULTY: END QUIZ ────────────────────────────
        else if (event === 'end-quiz') {
          await endQuizSession(quizId);
        }

        // ── 6. STUDENT: SUBMIT ANSWER ───────────────────────
        else if (event === 'submit-answer') {
          const { questionId, selectedIndex, timeTaken } = msg;
          const userId = ws.userId;
          if (!userId) return;

          const { rows: q } = await db.query(
            'SELECT options FROM quiz_questions WHERE id = $1',
            [questionId]
          );
          if (!q.length) return;

          const options = typeof q[0].options === 'string' ? JSON.parse(q[0].options) : q[0].options;
          const isCorrect = options[selectedIndex]?.isCorrect === true;
          const tTaken = Math.min(Math.max(timeTaken || 20, 0), 20);
          const score = isCorrect ? Math.round(100 + (50 * (1 - tTaken / 20))) : 0;
          const correctIndex = options.findIndex(o => o.isCorrect);

          const { rows: p } = await db.query(
            'SELECT * FROM quiz_participants WHERE quiz_id = $1 AND user_id = $2',
            [quizId, userId]
          );
          if (p.length) {
            const currentAnswers = Array.isArray(p[0].answers) ? p[0].answers :
              (typeof p[0].answers === 'string' ? JSON.parse(p[0].answers) : []);
            const newAnswers = [...currentAnswers, { questionId, selectedIndex, isCorrect, timeTaken: tTaken, score }];
            await db.query(
              `UPDATE quiz_participants SET answers = $1, total_score = total_score + $2
               WHERE quiz_id = $3 AND user_id = $4`,
              [JSON.stringify(newAnswers), score, quizId, userId]
            );
          }

          sendToClient(ws, {
            event: 'answer-result',
            isCorrect,
            score,
            correctIndex,
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
            await db.query('UPDATE quizzes SET current_question = $1 WHERE id = $2', [nextIndex, quizId]);
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
