// backend/src/index.js
require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const cron = require('node-cron');


// ── Routes ────────────────────────────────────────────────
const usersRouter = require('./routes/users.routes');
const postsRouter = require('./routes/posts.routes');
const connectRouter = require('./routes/connect.routes');
const tshareRouter = require('./routes/tshare.routes');
const notesRouter = require('./routes/notes.routes');
const jobsRouter = require('./routes/jobs.routes');
const productsRouter = require('./routes/products.routes');
const helpingRouter = require('./routes/helping.routes');
const adminRouter = require('./routes/admin.routes');
const dealsRouter = require('./routes/deals.routes');
const eventsRouter = require('./routes/events.routes');
const travelRouter = require('./routes/travel.routes');
const flatmatesRouter = require('./routes/flatmates.routes');
const quizRouter = require('./routes/quiz.routes');
const { activityLogger } = require('./middleware/activityLogger');

const app = express();
const server = http.createServer(app);

// ── Native WebSocket setup (matches Flutter web_socket_channel) ───
const { setupQuizWebSocket } = require('./socket/quiz.socket');
setupQuizWebSocket(server);


app.set('trust proxy', 1);
const PORT = process.env.PORT || 3000;

// ── Security & Logging ─────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'] }));
app.use(morgan('dev'));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Rate Limiting ──────────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api', globalLimiter);

// ── Static files (uploaded notes + quiz images) ───────────
app.use('/uploads', express.static(path.join(__dirname, '..', process.env.UPLOAD_DIR || 'uploads')));

// ── API Routes ─────────────────────────────────────────────
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/feed', postsRouter);
app.use('/api/v1/posts', postsRouter);
app.use('/api/v1/connect', connectRouter);
app.use('/api/v1/tshare', tshareRouter);
app.use('/api/v1/notes', notesRouter);
app.use('/api/v1/jobs', jobsRouter);
app.use('/api/v1/products', productsRouter);
app.use('/api/v1/helping', helpingRouter);
app.use('/api/v1/admin', adminRouter);
app.use('/api/v1/deals', dealsRouter);
app.use('/api/v1/events', eventsRouter);
app.use('/api/v1/travel', travelRouter);
app.use('/api/v1/flatmates', flatmatesRouter);
app.use('/api/v1/quiz', quizRouter);

// ── Admin: Faculty request endpoints ──────────────────────
const { requireAuth, requireAdmin } = require('./middleware/auth');
const fc = require('./controllers/facultyAuth.controller');
app.get('/api/v1/admin/faculty-requests', requireAuth, requireAdmin, fc.getFacultyRequests);
app.post('/api/v1/admin/faculty-requests/:id/approve', requireAuth, requireAdmin, fc.approveFacultyRequest);
app.post('/api/v1/admin/faculty-requests/:id/reject', requireAuth, requireAdmin, fc.rejectFacultyRequest);

// Activity logger — runs after auth middleware populates req.user
app.use('/api/v1', activityLogger);

// ── Health check ───────────────────────────────────────────
app.get('/health', (req, res) => {
  const { isConnected } = require('./config/redis');
  res.json({
    status: 'ok',
    ts: new Date().toISOString(),
    env: process.env.NODE_ENV,
    redis: isConnected ? 'connected' : 'disabled_or_connecting',
  });
});
app.get('/api/v1/health', (req, res) => {
  const { isConnected } = require('./config/redis');
  res.json({
    status: 'ok',
    ts: new Date().toISOString(),
    env: process.env.NODE_ENV,
    redis: isConnected ? 'connected' : 'disabled_or_connecting',
  });
});
app.get('/api/v1/chats', (req, res) => {
  res.json([]);
});
app.get('/api/v1/version', (req, res) => {
  try {
    const pkg = require('../package.json');
    res.json({ version: pkg.version, apkUrl: 'https://github.com/prateek155/campussetu/releases/latest/download/app-release.apk', notes: 'Update available on GitHub' });
  } catch (_) {
    res.json({ version: '1.0.0', apkUrl: 'https://github.com/prateek155/campussetu/releases/latest/download/app-release.apk' });
  }
});

// ── 404 handler ────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ── Error handler ──────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

// ── Safety: ensure all tables exist ──────────────────────
(async () => {
  const db = require('./config/db');
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      await db.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

      // Posts & social tables
      await db.query(`CREATE TABLE IF NOT EXISTS post_likes (
        post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (post_id, user_id))`);
      await db.query(`CREATE TABLE IF NOT EXISTS post_comments (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content TEXT NOT NULL CHECK (char_length(content) <= 500),
        created_at TIMESTAMPTZ DEFAULT NOW())`);
      await db.query(`CREATE TABLE IF NOT EXISTS points_ledger (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount INT NOT NULL, reason TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW())`);
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS campus_id TEXT UNIQUE`);
      await db.query(`CREATE UNIQUE INDEX IF NOT EXISTS uq_points_signup_once ON points_ledger (user_id) WHERE reason = 'signup_bonus'`);
      await db.query(`CREATE UNIQUE INDEX IF NOT EXISTS uq_points_milestone_once ON points_ledger (user_id, reason) WHERE reason LIKE 'post_like_milestone:%'`);

      // Travel rides table
      await db.query(`CREATE TABLE IF NOT EXISTS travel_rides (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        vehicle_type TEXT NOT NULL,
        destination TEXT NOT NULL,
        time_date TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        created_at TIMESTAMPTZ DEFAULT NOW())`);

      // Deals table
      await db.query(`CREATE TABLE IF NOT EXISTS deals (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        discount_code TEXT,
        banner_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW())`);

      // Events table
      await db.query(`CREATE TABLE IF NOT EXISTS events (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        place TEXT NOT NULL,
        time_date TEXT NOT NULL,
        registration_link TEXT NOT NULL,
        picture_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW())`);

      await db.query(`CREATE TABLE IF NOT EXISTS flatmates (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        poster_id UUID REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        place TEXT NOT NULL,
        num_persons INT DEFAULT 1,
        contact_number TEXT NOT NULL,
        description TEXT,
        photo_url_1 TEXT,
        photo_url_2 TEXT,
        status TEXT DEFAULT 'active',
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      // ── Faculty & Quiz tables ─────────────────────────────
      // Add role column to users
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'student'`);
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS college_name TEXT`);
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS subject TEXT`);

      // Faculty registration requests
      await db.query(`CREATE TABLE IF NOT EXISTS faculty_requests (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        college_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      // Quizzes
      await db.query(`CREATE TABLE IF NOT EXISTS quizzes (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        faculty_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        pin TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','waiting','live','ended')),
        current_question INT DEFAULT 0,
        ended_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      // Quiz questions
      await db.query(`CREATE TABLE IF NOT EXISTS quiz_questions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        question_text TEXT NOT NULL,
        image_url TEXT,
        options JSONB NOT NULL,
        order_index INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      // Quiz participants + scores
      await db.query(`CREATE TABLE IF NOT EXISTS quiz_participants (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        total_score INT DEFAULT 0,
        answers JSONB DEFAULT '[]',
        joined_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(quiz_id, user_id)
      )`);

      // Indexes
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quizzes_status ON quizzes (status, created_at DESC)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quizzes_faculty ON quizzes (faculty_id)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions (quiz_id, order_index)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_participants_quiz ON quiz_participants (quiz_id, total_score DESC)`);

      console.log('✅  DB tables ensured');
      return;
    } catch (e) {
      console.warn(`Table ensure attempt ${attempt}/5 failed:`, e.message);
      if (attempt < 5) await sleep(attempt * 3000);
    }
  }
})();

// ── Quiz Auto-Delete Cron (every 30 minutes) ──────────────
const { runAutoDelete } = require('./controllers/quiz.controller');
cron.schedule('*/30 * * * *', () => {
  runAutoDelete();
});

// ── Start ──────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`\n🚀  CampusSetu API running at http://localhost:${PORT}`);
  console.log(`📊  Health: http://localhost:${PORT}/health`);
  console.log(`🔌  WebSocket: ws://localhost:${PORT}/quiz`);

  console.log(`🌍  ENV: ${process.env.NODE_ENV || 'development'}\n`);
});

module.exports = app;
