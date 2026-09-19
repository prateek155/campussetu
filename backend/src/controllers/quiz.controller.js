// backend/src/controllers/quiz.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const cache = require('../config/redis');


// ── Multer setup for question images ──────────────────────────
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../uploads/quiz');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `quiz-${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('Only images allowed'));
  },
});
exports.uploadMiddleware = upload.single('image');

// ── Helpers ───────────────────────────────────────────────────
async function getUserId(firebaseUid) {
  const { rows } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [firebaseUid]);
  return rows.length ? rows[0].id : null;
}

function fullUrl(req, p) {
  if (!p) return null;
  if (p.startsWith('http')) return p;
  return `${req.protocol}://${req.get('host')}${p}`;
}

function generatePin() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

// ── FACULTY: Get profile ──────────────────────────────────────
exports.getFacultyProfile = async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, name, email, role FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    if (rows[0].role !== 'faculty' && !rows[0].is_admin) {
      return res.status(403).json({ error: 'Faculty access required' });
    }
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Create Quiz ──────────────────────────────────────
exports.createQuiz = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });

    // verify faculty role
    const { rows: urows } = await db.query('SELECT role, is_admin FROM users WHERE id = $1', [facultyId]);
    if (!urows.length || (urows[0].role !== 'faculty' && !urows[0].is_admin)) {
      return res.status(403).json({ error: 'Faculty access required' });
    }

    const { title, questions } = req.body;
    if (!title) return res.status(400).json({ error: 'title required' });
    if (!questions || !Array.isArray(questions) || questions.length === 0) {
      return res.status(400).json({ error: 'At least 1 question required' });
    }

    // Generate unique PIN
    let pin;
    for (let i = 0; i < 10; i++) {
      pin = generatePin();
      const { rows: exists } = await db.query(
        "SELECT id FROM quizzes WHERE pin = $1 AND status != 'ended'", [pin]
      );
      if (!exists.length) break;
    }

    const quizId = uuidv4();
    await db.query(
      `INSERT INTO quizzes (id, faculty_id, title, pin, status)
       VALUES ($1, $2, $3, $4, 'draft')`,
      [quizId, facultyId, title.trim(), pin]
    );

    // Insert questions
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      if (!q.question_text || !q.options || q.options.length !== 4) continue;
      await db.query(
        `INSERT INTO quiz_questions (id, quiz_id, question_text, image_url, options, order_index)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [uuidv4(), quizId, q.question_text.trim(), q.image_url || null, JSON.stringify(q.options), i]
      );
    }

    const { rows } = await db.query('SELECT * FROM quizzes WHERE id = $1', [quizId]);
    res.status(201).json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Upload question image ────────────────────────────
exports.uploadQuestionImage = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
    const url = `/uploads/quiz/${req.file.filename}`;
    res.json({ url: fullUrl(req, url) });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Get my quizzes ───────────────────────────────────
exports.getMyQuizzes = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `SELECT q.*,
        (SELECT COUNT(*)::int FROM quiz_participants p WHERE p.quiz_id = q.id) AS participant_count,
        (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count
       FROM quizzes q WHERE q.faculty_id = $1 ORDER BY q.created_at DESC`,
      [facultyId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Get single quiz with questions ───────────────────
exports.getQuizDetail = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows } = await db.query('SELECT * FROM quizzes WHERE id = $1 AND faculty_id = $2', [req.params.id, facultyId]);
    if (!rows.length) return res.status(404).json({ error: 'Quiz not found' });

    const { rows: questions } = await db.query(
      'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC',
      [req.params.id]
    );
    // Add full URLs
    questions.forEach(q => { q.image_url = fullUrl(req, q.image_url); });
    res.json({ ...rows[0], questions });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Start quiz (waiting → live) ─────────────────────
exports.startQuiz = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows } = await db.query(
      "UPDATE quizzes SET status = 'waiting' WHERE id = $1 AND faculty_id = $2 AND status = 'draft' RETURNING *",
      [req.params.id, facultyId]
    );
    if (!rows.length) return res.status(400).json({ error: 'Quiz not found or already started' });
    await cache.delCache('quiz:live', 'home:counts');
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: End quiz ─────────────────────────────────────────
exports.endQuiz = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows } = await db.query(
      "UPDATE quizzes SET status = 'ended', ended_at = NOW() WHERE id = $1 AND faculty_id = $2 AND status != 'ended' RETURNING *",
      [req.params.id, facultyId]
    );
    if (!rows.length) return res.status(400).json({ error: 'Quiz not found or already ended' });
    await cache.delCache('quiz:live', 'home:counts');
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Get full results ─────────────────────────────────
exports.getResults = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows: quiz } = await db.query('SELECT * FROM quizzes WHERE id = $1 AND faculty_id = $2', [req.params.id, facultyId]);
    if (!quiz.length) return res.status(404).json({ error: 'Quiz not found' });

    const { rows: participants } = await db.query(
      `SELECT p.*, u.name, u.email
       FROM quiz_participants p
       JOIN users u ON u.id = p.user_id
       WHERE p.quiz_id = $1
       ORDER BY p.total_score DESC, p.joined_at ASC`,
      [req.params.id]
    );

    const { rows: questions } = await db.query(
      'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC',
      [req.params.id]
    );

    // Add rank
    const ranked = participants.map((p, i) => ({ ...p, rank: i + 1 }));
    res.json({ quiz: quiz[0], participants: ranked, questions });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── STUDENT: Get live quizzes ─────────────────────────────────
exports.getLiveQuizzes = async (req, res) => {
  try {
    const cached = await cache.getCache('quiz:live');
    if (cached) {
      try { return res.json(JSON.parse(cached)); } catch (_) {}
    }

    const { rows } = await db.query(
      `SELECT q.id, q.title, q.pin, q.status, q.created_at,
        u.name AS faculty_name,
        (SELECT COUNT(*)::int FROM quiz_participants p WHERE p.quiz_id = q.id) AS participant_count,
        (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count
       FROM quizzes q
       JOIN users u ON u.id = q.faculty_id
       WHERE q.status IN ('waiting', 'live')
       ORDER BY q.created_at DESC`,
    );
    await cache.setCache('quiz:live', JSON.stringify(rows), 15); // 15s cache
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};


// ── STUDENT: Join quiz by PIN ─────────────────────────────────
exports.joinQuiz = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });

    const { pin } = req.body;
    if (!pin) return res.status(400).json({ error: 'PIN required' });

    const { rows: quiz } = await db.query(
      "SELECT * FROM quizzes WHERE pin = $1 AND status IN ('waiting', 'live')",
      [pin]
    );
    if (!quiz.length) return res.status(404).json({ error: 'Quiz not found or not active. Check your PIN.' });

    // Upsert participant
    await db.query(
      `INSERT INTO quiz_participants (id, quiz_id, user_id)
       VALUES ($1, $2, $3) ON CONFLICT (quiz_id, user_id) DO NOTHING`,
      [uuidv4(), quiz[0].id, userId]
    );

    const { rows: questions } = await db.query(
      'SELECT id, question_text, image_url, options, order_index FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC',
      [quiz[0].id]
    );

    // Hide correct answer from students
    const sanitizedQuestions = questions.map(q => ({
      ...q,
      options: (typeof q.options === 'string' ? JSON.parse(q.options) : q.options).map(o => ({ text: o.text })),
    }));

    res.json({ quiz: quiz[0], questions: sanitizedQuestions });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── STUDENT: Submit answer ────────────────────────────────────
exports.submitAnswer = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });

    const { quiz_id, question_id, selected_index, time_taken } = req.body;

    // Get correct answer
    const { rows: q } = await db.query('SELECT options FROM quiz_questions WHERE id = $1', [question_id]);
    if (!q.length) return res.status(404).json({ error: 'Question not found' });

    const options = typeof q[0].options === 'string' ? JSON.parse(q[0].options) : q[0].options;
    const isCorrect = options[selected_index]?.isCorrect === true;
    // Score: correct = base 100 + speed bonus (max 50 for instant, 0 for 20s)
    const timeTaken = Math.min(Math.max(time_taken || 20, 0), 20);
    const score = isCorrect ? Math.round(100 + (50 * (1 - timeTaken / 20))) : 0;

    // Get current participant record
    const { rows: p } = await db.query(
      'SELECT * FROM quiz_participants WHERE quiz_id = $1 AND user_id = $2',
      [quiz_id, userId]
    );
    if (!p.length) return res.status(400).json({ error: 'Join quiz first' });

    const currentAnswers = p[0].answers || [];
    const newAnswers = [...currentAnswers, { question_id, selected_index, isCorrect, time_taken: timeTaken, score }];

    await db.query(
      `UPDATE quiz_participants SET answers = $1, total_score = total_score + $2
       WHERE quiz_id = $3 AND user_id = $4`,
      [JSON.stringify(newAnswers), score, quiz_id, userId]
    );

    res.json({ isCorrect, score });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── STUDENT: Get my result ────────────────────────────────────
exports.getMyResult = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });

    // Get all participants ranked
    const { rows: all } = await db.query(
      `SELECT p.user_id, p.total_score, u.name
       FROM quiz_participants p JOIN users u ON u.id = p.user_id
       WHERE p.quiz_id = $1
       ORDER BY p.total_score DESC, p.joined_at ASC`,
      [req.params.id]
    );

    const myIndex = all.findIndex(p => p.user_id === userId);
    const myRank = myIndex + 1;
    const top3 = all.slice(0, 3).map((p, i) => ({ ...p, rank: i + 1 }));
    const myData = all[myIndex] ? { ...all[myIndex], rank: myRank } : null;

    res.json({ top3, my_result: myData, total_participants: all.length });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── AUTO-DELETE CRON ──────────────────────────────────────────
async function runAutoDelete() {
  try {
    const { rowCount } = await db.query(
      `DELETE FROM quizzes WHERE status = 'ended' AND ended_at < NOW() - INTERVAL '5 hours'`
    );
    if (rowCount > 0) console.log(`🗑️  Auto-deleted ${rowCount} expired quiz(zes)`);
  } catch (err) { console.error('Quiz auto-delete error:', err.message); }
}
exports.runAutoDelete = runAutoDelete;
