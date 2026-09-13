// backend/src/index.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

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
const { activityLogger } = require('./middleware/activityLogger');
const app = express();
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

// ── Static files (uploaded notes) ──────────────────────────
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

// Activity logger — runs after auth middleware populates req.user
app.use('/api/v1', activityLogger);

// ── Health check ───────────────────────────────────────────
app.get('/health', (req, res) => {
  const { redis } = require('./config/redis');
  res.json({
    status: 'ok',
    ts: new Date().toISOString(),
    env: process.env.NODE_ENV,
    redis: redis ? 'connected' : 'disabled',
  });
});
app.get('/api/v1/health', (req, res) => {
  const { redis } = require('./config/redis');
  res.json({
    status: 'ok',
    ts: new Date().toISOString(),
    env: process.env.NODE_ENV,
    redis: redis ? 'connected' : 'disabled',
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

// ── Safety: ensure all tables exist (older DBs / cold starts) ──
// Retries with backoff: Neon cold-start often drops the first connection.
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

      // Travel rides table (time_date & contact_number kept as TEXT to match schema.sql)
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

      // Events table (time_date kept as TEXT to match schema.sql)
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

      console.log('✅  DB tables ensured');
      return;
    } catch (e) {
      console.warn(`Table ensure attempt ${attempt}/5 failed:`, e.message);
      if (attempt < 5) await sleep(attempt * 3000);
    }
  }
})();

// ── Start ──────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🚀  CampusSetu API running at http://localhost:${PORT}`);
  console.log(`📊  Health: http://localhost:${PORT}/health`);
  console.log(`🌍  ENV: ${process.env.NODE_ENV || 'development'}\n`);
});

module.exports = app;
