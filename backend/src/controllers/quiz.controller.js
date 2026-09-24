// backend/src/controllers/quiz.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const cache = require('../config/redis');
const { submitQuizAnswer } = require('../services/quizAnswer.service');


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
      'SELECT id, name, email, role, is_admin FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    if (rows[0].role !== 'faculty' && !rows[0].is_admin) {
      return res.status(403).json({ error: 'Faculty access required' });
    }
    const { id, name, email, role } = rows[0];
    res.json({ id, name, email, role });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── FACULTY: Create Quiz ──────────────────────────────────────
exports.createQuiz = async (req, res) => {
  let client;
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });

    // verify faculty role
    const { rows: urows } = await db.query('SELECT role, is_admin FROM users WHERE id = $1', [facultyId]);
    if (!urows.length || (urows[0].role !== 'faculty' && !urows[0].is_admin)) {
      return res.status(403).json({ error: 'Faculty access required' });
    }

    const { title, questions, mode = 'live' } = req.body || {};
    const durationMinutes = Number(req.body?.duration_minutes ?? 60);
    const allowedSettings = ['allow_copy', 'screenshot_deterrent', 'lock_tab_switch', 'shuffle_questions', 'shuffle_options'];
    const settings = {};
    for (const key of allowedSettings) settings[key] = req.body?.settings?.[key] === true;

    if (typeof title !== 'string' || !title.trim() || title.trim().length > 160) {
      return res.status(400).json({ error: 'Title must contain 1 to 160 characters' });
    }
    if (!['live', 'paper'].includes(mode)) {
      return res.status(400).json({ error: 'mode must be live or paper' });
    }
    if (!Number.isInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 600) {
      return res.status(400).json({ error: 'duration_minutes must be between 1 and 600' });
    }
    if (!Array.isArray(questions) || questions.length < 1 || questions.length > 100) {
      return res.status(400).json({ error: 'Add between 1 and 100 questions' });
    }
    for (const [index, question] of questions.entries()) {
      const options = question?.options;
      if (typeof question?.question_text !== 'string' || !question.question_text.trim() || question.question_text.trim().length > 2000) {
        return res.status(400).json({ error: `Question ${index + 1} must contain text (up to 2000 characters)` });
      }
      if (!Array.isArray(options) || options.length !== 4 || options.some((option) => typeof option?.text !== 'string' || !option.text.trim() || option.text.length > 500)) {
        return res.status(400).json({ error: `Question ${index + 1} must have four non-empty options` });
      }
      if (options.filter((option) => option.isCorrect === true).length !== 1) {
        return res.status(400).json({ error: `Question ${index + 1} must have exactly one correct option` });
      }
      const marks = question.marks == null ? 1 : Number(question.marks);
      if (!Number.isInteger(marks) || marks < 1 || marks > 100) {
        return res.status(400).json({ error: `Question ${index + 1} marks must be between 1 and 100` });
      }
    }

    client = await db.connect();
    await client.query('BEGIN');
    const quizId = uuidv4();
    let pin;
    let uniquePin = false;
    for (let i = 0; i < 20; i++) {
      pin = generatePin();
      const { rows: exists } = await client.query('SELECT id FROM quizzes WHERE pin = $1', [pin]);
      if (!exists.length) { uniquePin = true; break; }
    }
    if (!uniquePin) throw new Error('Could not generate an assessment PIN; try again');

    await client.query(
      `INSERT INTO quizzes (id, faculty_id, title, pin, status, mode, duration_minutes, settings)
       VALUES ($1, $2, $3, $4, 'draft', $5, $6, $7::jsonb)`,
      [quizId, facultyId, title.trim(), pin, mode, durationMinutes, JSON.stringify(settings)]
    );

    // Insert questions
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      await client.query(
        `INSERT INTO quiz_questions (id, quiz_id, question_text, image_url, options, marks, order_index)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)`,
        [uuidv4(), quizId, q.question_text.trim(), q.image_url || null, JSON.stringify(q.options), Number(q.marks ?? 1), i]
      );
    }

    const { rows } = await client.query('SELECT * FROM quizzes WHERE id = $1', [quizId]);
    await client.query('COMMIT');
    await cache.delCache('quiz:live');
    res.status(201).json(rows[0]);
  } catch (err) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    console.error('Assessment creation failed:', err.code || err.message);
    res.status(500).json({ error: 'Unable to create assessment' });
  } finally {
    client?.release();
  }
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
        (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count,
        (SELECT COUNT(*)::int FROM quiz_submissions s WHERE s.quiz_id = q.id) AS submission_count
       FROM quizzes q WHERE q.faculty_id = $1 ORDER BY q.created_at DESC LIMIT 100`,
      [facultyId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// One grouped read for the analytics overview; detailed student rows remain on the results page.
exports.getFacultyAnalytics = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });
    const { rows } = await db.query(
      `SELECT q.id AS quiz_id, q.mode, q.status,
         CASE WHEN q.mode = 'paper' THEN COALESCE(ps.submission_count, 0) ELSE COALESCE(ls.participant_count, 0) END AS participant_count,
         CASE WHEN q.mode = 'paper' THEN COALESCE(ps.submission_count, 0) ELSE COALESCE(ls.participant_count, 0) END AS score_count,
         CASE WHEN q.mode = 'paper' THEN ps.average_score ELSE ls.average_score END AS average_score
       FROM quizzes q
       LEFT JOIN LATERAL (
         SELECT COUNT(*)::int AS participant_count, AVG(total_score)::numeric AS average_score
         FROM quiz_participants WHERE quiz_id = q.id
       ) ls ON q.mode != 'paper'
       LEFT JOIN LATERAL (
         SELECT COUNT(*)::int AS submission_count, AVG(total_score)::numeric AS average_score
         FROM quiz_submissions WHERE quiz_id = q.id
       ) ps ON q.mode = 'paper'
       WHERE q.faculty_id = $1
       ORDER BY q.created_at DESC
       LIMIT 100`,
      [facultyId]
    );
    res.json({ assessments: rows });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

exports.getQuestionBank = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });
    const { rows } = await db.query(
      `SELECT qq.id, qq.quiz_id, qq.question_text, qq.options, qq.marks, qq.created_at, q.title AS quiz_title
       FROM quiz_questions qq JOIN quizzes q ON q.id = qq.quiz_id
       WHERE q.faculty_id = $1 ORDER BY qq.created_at DESC LIMIT 250`,
      [facultyId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

exports.updatePaperTest = async (req, res) => {
  let client;
  try {
    const facultyId = await getUserId(req.user.uid);
    if (!facultyId) return res.status(404).json({ error: 'User not found' });
    const { title, questions, duration_minutes: rawDuration, settings: rawSettings } = req.body || {};
    const duration = Number(rawDuration ?? 60);
    if (typeof title !== 'string' || !title.trim() || title.trim().length > 160) {
      return res.status(400).json({ error: 'Title must contain 1 to 160 characters' });
    }
    if (!Number.isInteger(duration) || duration < 1 || duration > 600) {
      return res.status(400).json({ error: 'Duration must be between 1 and 600 minutes' });
    }
    if (!Array.isArray(questions) || questions.length < 1 || questions.length > 100) {
      return res.status(400).json({ error: 'Add between 1 and 100 questions' });
    }
    for (const [index, question] of questions.entries()) {
      const options = question?.options;
      if (typeof question?.question_text !== 'string' || !question.question_text.trim() || question.question_text.trim().length > 2000 ||
          !Array.isArray(options) || options.length !== 4 ||
          options.some((option) => typeof option?.text !== 'string' || !option.text.trim() || option.text.length > 500) ||
          options.filter((option) => option.isCorrect === true).length !== 1) {
        return res.status(400).json({ error: `Question ${index + 1} must have text, four options, and one correct answer` });
      }
    }
    const settingKeys = ['allow_copy', 'screenshot_deterrent', 'lock_tab_switch', 'shuffle_questions', 'shuffle_options'];
    const settings = Object.fromEntries(settingKeys.map((key) => [key, rawSettings?.[key] === true]));

    client = await db.connect();
    await client.query('BEGIN');
    const { rows: existing } = await client.query(
      `SELECT id FROM quizzes WHERE id = $1 AND faculty_id = $2 AND mode = 'paper' AND status = 'draft' FOR UPDATE`,
      [req.params.id, facultyId]
    );
    if (!existing.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Draft test not found or already published' });
    }
    await client.query(
      'UPDATE quizzes SET title = $1, duration_minutes = $2, settings = $3::jsonb WHERE id = $4',
      [title.trim(), duration, JSON.stringify(settings), req.params.id]
    );
    await client.query('DELETE FROM quiz_questions WHERE quiz_id = $1', [req.params.id]);
    for (const [index, question] of questions.entries()) {
      await client.query(
        `INSERT INTO quiz_questions (id, quiz_id, question_text, image_url, options, marks, order_index)
         VALUES ($1, $2, $3, $4, $5::jsonb, 1, $6)`,
        [uuidv4(), req.params.id, question.question_text.trim(), question.image_url || null, JSON.stringify(question.options), index]
      );
    }
    const { rows } = await client.query('SELECT * FROM quizzes WHERE id = $1', [req.params.id]);
    await client.query('COMMIT');
    res.json(rows[0]);
  } catch (err) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    console.error('Paper test draft update failed:', err.code || 'unknown error');
    res.status(500).json({ error: 'Unable to save paper test draft' });
  } finally {
    client?.release();
  }
};

// ── FACULTY: Get single quiz with questions ───────────────────
exports.getQuizDetail = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows } = await db.query('SELECT * FROM quizzes WHERE id = $1 AND faculty_id = $2', [req.params.id, facultyId]);
    if (!rows.length) return res.status(404).json({ error: 'Quiz not found' });

    const { rows: questions } = await db.query(
      'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC, id ASC',
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
      "UPDATE quizzes SET status = 'waiting' WHERE id = $1 AND faculty_id = $2 AND mode = 'live' AND status = 'draft' RETURNING *",
      [req.params.id, facultyId]
    );
    if (!rows.length) {
      const { rows: existing } = await db.query(
        "SELECT * FROM quizzes WHERE id = $1 AND faculty_id = $2 AND mode = 'live' AND status = 'waiting'",
        [req.params.id, facultyId]
      );
      if (!existing.length) return res.status(400).json({ error: 'Quiz not found or already started' });
      return res.json(existing[0]);
    }
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

    if (quiz[0].mode === 'paper') {
      const { rows: submissions } = await db.query(
        `SELECT s.id, COALESCE(s.total_score, 0) AS total_score, COALESCE(s.answers, '[]'::jsonb) AS answers,
           s.submitted_at, a.started_at, u.name, u.email,
           (SELECT COUNT(*)::int FROM quiz_test_events e WHERE e.quiz_id = a.quiz_id AND e.user_id = a.user_id AND e.event_type = 'tab_switch') AS violation_count
         FROM quiz_test_attempts a JOIN users u ON u.id = a.user_id
         LEFT JOIN quiz_submissions s ON s.quiz_id = a.quiz_id AND s.user_id = a.user_id
         WHERE a.quiz_id = $1 ORDER BY s.total_score DESC NULLS LAST, a.started_at ASC`,
        [req.params.id]
      );
      const { rows: questions } = await db.query(
        'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC, id ASC',
        [req.params.id]
      );
      return res.json({
        quiz: quiz[0],
        participants: submissions.map((submission, i) => ({ ...submission, rank: i + 1 })),
        questions,
      });
    }

    const { rows: participants } = await db.query(
      `SELECT p.*, u.name, u.email
       FROM quiz_participants p
       JOIN users u ON u.id = p.user_id
       WHERE p.quiz_id = $1
       ORDER BY p.total_score DESC, p.joined_at ASC`,
      [req.params.id]
    );

    const { rows: questions } = await db.query(
      'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC, id ASC',
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
       WHERE q.mode = 'live' AND q.status IN ('waiting', 'live')
       ORDER BY q.created_at DESC
       LIMIT 100`,
    );
    await cache.setCache('quiz:live', JSON.stringify(rows), 15); // 15s cache
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── STUDENT: Published paper tests ───────────────────────────
exports.getPaperTests = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });
    const { rows } = await db.query(
      `SELECT q.id, q.title, q.duration_minutes, q.settings, q.created_at,
         u.name AS faculty_name,
         (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count,
         EXISTS (SELECT 1 FROM quiz_submissions s WHERE s.quiz_id = q.id AND s.user_id = $1) AS submitted
       FROM quizzes q JOIN users u ON u.id = q.faculty_id
       WHERE q.mode = 'paper' AND q.status = 'live'
       ORDER BY q.created_at DESC
       LIMIT 100`,
      [userId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── STUDENT: Get a published test with answers hidden ─────────
exports.getPaperTest = async (req, res) => {
  let client;
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });
    client = await db.connect();
    await client.query('BEGIN');
    const { rows: tests } = await client.query(
      `SELECT id, title, duration_minutes, settings, status FROM quizzes
       WHERE id = $1 AND mode = 'paper' AND status = 'live' FOR SHARE`,
      [req.params.id]
    );
    if (!tests.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Test not found or closed' });
    }
    const { rows: submissions } = await client.query(
      'SELECT total_score, submitted_at FROM quiz_submissions WHERE quiz_id = $1 AND user_id = $2',
      [req.params.id, userId]
    );
    if (submissions.length) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'You have already submitted this test', score: submissions[0].total_score });
    }
    await client.query(
      'INSERT INTO quiz_test_attempts (quiz_id, user_id) VALUES ($1, $2) ON CONFLICT (quiz_id, user_id) DO NOTHING',
      [req.params.id, userId]
    );
    const { rows: attempts } = await client.query(
      `SELECT started_at, answers,
         (SELECT COUNT(*)::int FROM quiz_test_events e WHERE e.quiz_id = quiz_test_attempts.quiz_id
           AND e.user_id = quiz_test_attempts.user_id AND e.event_type = 'tab_switch') AS violation_count
       FROM quiz_test_attempts WHERE quiz_id = $1 AND user_id = $2`,
      [req.params.id, userId]
    );
    const { rows: questions } = await client.query(
      'SELECT id, question_text, image_url, options, marks, order_index FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index, id',
      [req.params.id]
    );
    await client.query('COMMIT');
    res.json({
      ...tests[0],
      started_at: attempts[0].started_at,
      saved_answers: attempts[0].answers || {},
      violation_count: attempts[0].violation_count,
      questions: questions.map((question) => ({
        ...question,
        options: (typeof question.options === 'string' ? JSON.parse(question.options) : question.options).map(({ text }) => ({ text })),
      })),
    });
  } catch (err) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    res.status(500).json({ error: err.message });
  } finally {
    client?.release();
  }
};

exports.savePaperTestAnswer = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });
    const questionId = req.body?.question_id;
    const selectedIndex = req.body?.selected_index;
    if (typeof questionId !== 'string' || !Number.isInteger(selectedIndex) || selectedIndex < 0 || selectedIndex > 3) {
      return res.status(400).json({ error: 'A valid question and option are required' });
    }
    const { rowCount } = await db.query(
      `UPDATE quiz_test_attempts a
       SET answers = jsonb_set(COALESCE(a.answers, '{}'::jsonb), ARRAY[$3::text], to_jsonb($4::int), true)
       FROM quizzes q, quiz_questions qq
       WHERE a.quiz_id = $1 AND a.user_id = $2
         AND q.id = a.quiz_id AND q.mode = 'paper' AND q.status = 'live'
         AND a.started_at + (q.duration_minutes * INTERVAL '1 minute') > NOW()
         AND qq.quiz_id = q.id AND qq.id = $3::uuid
         AND $4::int < jsonb_array_length(qq.options)
         AND NOT EXISTS (SELECT 1 FROM quiz_submissions s WHERE s.quiz_id = a.quiz_id AND s.user_id = a.user_id)`,
      [req.params.id, userId, questionId, selectedIndex]
    );
    if (!rowCount) return res.status(409).json({ error: 'Test attempt is missing, closed, or expired' });
    res.json({ saved: true });
  } catch (err) {
    res.status(500).json({ error: 'Unable to save answer' });
  }
};

// ── STUDENT: Submit a paper test; server grades and stores one attempt ──
exports.submitPaperTest = async (req, res) => {
  let client;
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });
    const submittedAnswers = req.body?.answers;
    if (!submittedAnswers || typeof submittedAnswers !== 'object' || Array.isArray(submittedAnswers)) {
      return res.status(400).json({ error: 'answers must map question IDs to selected option indexes' });
    }

    client = await db.connect();
    await client.query('BEGIN');
    const { rows: tests } = await client.query(
      'SELECT id, status, mode, duration_minutes FROM quizzes WHERE id = $1 FOR UPDATE', [req.params.id]
    );
    if (!tests.length || tests[0].mode !== 'paper') {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Test not found' });
    }
    const { rows: previous } = await client.query(
      'SELECT total_score, submitted_at FROM quiz_submissions WHERE quiz_id = $1 AND user_id = $2',
      [req.params.id, userId]
    );
    if (previous.length) {
      await client.query('COMMIT');
      return res.json({ submitted: true, alreadySubmitted: true, score: previous[0].total_score, submitted_at: previous[0].submitted_at });
    }
    if (tests[0].status !== 'live') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Test is closed' });
    }
    const { rows: attempts } = await client.query(
      `SELECT EXTRACT(EPOCH FROM (NOW() - started_at)) / 60 AS elapsed_minutes
       FROM quiz_test_attempts WHERE quiz_id = $1 AND user_id = $2`,
      [req.params.id, userId]
    );
    if (!attempts.length) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Open the test before submitting your answers' });
    }
    if (Number(attempts[0].elapsed_minutes) > Number(tests[0].duration_minutes)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'The test time has expired' });
    }
    const { rows: questions } = await client.query(
      'SELECT id, options, marks FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index, id',
      [req.params.id]
    );
    const validIds = new Set(questions.map((question) => String(question.id)));
    if (Object.keys(submittedAnswers).some((id) => !validIds.has(id))) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'An answer belongs to a different test' });
    }

    let score = 0;
    const answers = questions.map((question) => {
      const selectedIndex = submittedAnswers[question.id];
      const options = typeof question.options === 'string' ? JSON.parse(question.options) : question.options;
      const validSelection = Number.isInteger(selectedIndex) && selectedIndex >= 0 && selectedIndex < options.length;
      const correctIndex = options.findIndex((option) => option.isCorrect === true);
      const isCorrect = validSelection && selectedIndex === correctIndex;
      const points = isCorrect ? Number(question.marks) || 1 : 0;
      score += points;
      return { question_id: question.id, selected_index: validSelection ? selectedIndex : null, isCorrect, score: points, correct_index: correctIndex };
    });
    const { rows: inserted } = await client.query(
      `INSERT INTO quiz_submissions (quiz_id, user_id, answers, total_score)
       VALUES ($1, $2, $3::jsonb, $4)
       ON CONFLICT (quiz_id, user_id) DO NOTHING
       RETURNING total_score, submitted_at`,
      [req.params.id, userId, JSON.stringify(answers), score]
    );
    const result = inserted[0] || (await client.query(
      'SELECT total_score, submitted_at FROM quiz_submissions WHERE quiz_id = $1 AND user_id = $2',
      [req.params.id, userId]
    )).rows[0];
    await client.query('COMMIT');
    res.json({ submitted: true, alreadySubmitted: !inserted.length, score: result.total_score, submitted_at: result.submitted_at });
  } catch (err) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    console.error('Paper test submission failed:', err.code || 'unknown error');
    res.status(500).json({ error: 'Unable to submit test' });
  } finally {
    client?.release();
  }
};

// ── FACULTY: Publish a paper test ─────────────────────────────
exports.publishPaperTest = async (req, res) => {
  try {
    const facultyId = await getUserId(req.user.uid);
    const { rows } = await db.query(
      `UPDATE quizzes SET status = 'live' WHERE id = $1 AND faculty_id = $2 AND mode = 'paper' AND status = 'draft'
       AND EXISTS (SELECT 1 FROM quiz_questions WHERE quiz_id = quizzes.id) RETURNING *`,
      [req.params.id, facultyId]
    );
    if (!rows.length) return res.status(400).json({ error: 'Test not found, already published, or has no questions' });
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

exports.recordPaperTestFlag = async (req, res) => {
  try {
    const userId = await getUserId(req.user.uid);
    if (!userId) return res.status(404).json({ error: 'User not found' });
    const { rows: tests } = await db.query(
      "SELECT settings FROM quizzes WHERE id = $1 AND mode = 'paper' AND status = 'live'",
      [req.params.id]
    );
    if (!tests.length) return res.status(404).json({ error: 'Test not found or closed' });
    if (tests[0].settings?.lock_tab_switch !== true) return res.status(409).json({ error: 'Tab switching is not being monitored for this test' });
    const { rows: attempts } = await db.query(
      'SELECT id FROM quiz_test_attempts WHERE quiz_id = $1 AND user_id = $2',
      [req.params.id, userId]
    );
    if (!attempts.length) return res.status(403).json({ error: 'Open the test before sending events' });
    await db.query(
      `INSERT INTO quiz_test_events (quiz_id, user_id, event_type)
       SELECT $1, $2, 'tab_switch'
       WHERE NOT EXISTS (
         SELECT 1 FROM quiz_test_events
         WHERE quiz_id = $1 AND user_id = $2 AND event_type = 'tab_switch'
           AND created_at > NOW() - INTERVAL '10 seconds'
       )`,
      [req.params.id, userId]
    );
    const { rows } = await db.query(
      "SELECT COUNT(*)::int AS count FROM quiz_test_events WHERE quiz_id = $1 AND user_id = $2 AND event_type = 'tab_switch'",
      [req.params.id, userId]
    );
    res.json({ violation_count: rows[0].count });
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
      "SELECT * FROM quizzes WHERE pin = $1 AND mode = 'live' AND status IN ('waiting', 'live')",
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
      'SELECT id, question_text, image_url, options, order_index FROM quiz_questions WHERE quiz_id = $1 ORDER BY order_index ASC, id ASC',
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

    const { quiz_id, question_id, selected_index } = req.body || {};
    const isUuid = (value) => typeof value === 'string' &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
    if (!isUuid(quiz_id) || !isUuid(question_id)) {
      return res.status(400).json({ error: 'Valid quiz_id and question_id are required' });
    }
    if (!Number.isInteger(selected_index) || selected_index < 0) {
      return res.status(400).json({ error: 'selected_index must be a non-negative integer' });
    }

    const result = await submitQuizAnswer({
      quizId: quiz_id,
      questionId: question_id,
      userId,
      selectedIndex: selected_index,
    });
    res.json({ isCorrect: result.isCorrect, score: result.score, alreadySubmitted: result.alreadySubmitted });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    console.error('Quiz answer submission failed:', err.code || 'unknown error');
    res.status(500).json({ error: 'Unable to submit quiz answer' });
  }
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
