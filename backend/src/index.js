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
const reportsRouter = require('./routes/reports.routes');
const alarmWallpaperRouter = require('./routes/alarmWallpaper.routes');
const resumesRouter = require('./routes/resumes.routes');
const ambassadorRouter = require('./routes/ambassador.routes');
const enterpriseRouter = require('./routes/enterprise.routes');

const app = express();
const server = http.createServer(app);

// ── Native WebSocket setup (matches Flutter web_socket_channel) ───
const { setupQuizWebSocket } = require('./socket/quiz.socket');
setupQuizWebSocket(server);


app.set('trust proxy', 1);
const PORT = process.env.PORT || 3000;

// ── Security & Logging ─────────────────────────────────────
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
  crossOriginOpenerPolicy: false,
}));
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With', 'Idempotency-Key'],
}));
app.options('*', cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Rate Limiting ──────────────────────────────────────────
const { redis } = require('./config/redis');
const createRateLimitStore = (prefix) => {
  try {
    if (!redis) return undefined;
    const { RedisStore } = require('rate-limit-redis');
    return new RedisStore({
      sendCommand: (...args) => redis.call(...args),
      prefix,
    });
  } catch {
    // Redis-backed limits are optional; database signup/login guards remain shared.
    return undefined;
  }
};

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore('rl:global:'),
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore('rl:auth:'),
  message: { error: 'Too many attempts. Please try again in 15 minutes.' },
});

const signupDeviceLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: createRateLimitStore('rl:signup-device:'),
  message: { error: 'Too many signup attempts from this connection. Please wait and try again.' },
});

app.use('/api', globalLimiter);
app.use('/api/v1/users/login', authLimiter);
app.use('/api/v1/users/register', authLimiter);
app.use('/api/v1/users/signup-device', signupDeviceLimiter);

// ── Static files (uploaded notes + quiz images) ───────────
app.use('/uploads', express.static(path.join(__dirname, '..', process.env.UPLOAD_DIR || 'uploads')));

// ── API Routes ─────────────────────────────────────────────
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/ambassador', ambassadorRouter);
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
app.use('/api/v1/reports', reportsRouter);
app.use('/api/v1/alarm-wallpapers', alarmWallpaperRouter);
app.use('/api/v1/resumes', resumesRouter);
app.use('/api/v1/enterprise', enterpriseRouter);

// ── Admin: Faculty request endpoints ──────────────────────
const { requireAuth, requireAdmin } = require('./middleware/auth');
const fc = require('./controllers/facultyAuth.controller');
app.get('/api/v1/admin/faculty-requests', requireAuth, requireAdmin, fc.getFacultyRequests);
app.post('/api/v1/admin/faculty-requests/:id/approve', requireAuth, requireAdmin, fc.approveFacultyRequest);
app.post('/api/v1/admin/faculty-requests/:id/reject', requireAuth, requireAdmin, fc.rejectFacultyRequest);

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

      // Authentication abuse controls
      await db.query('CREATE TABLE IF NOT EXISTS auth_login_attempts (attempt_key CHAR(64) PRIMARY KEY, failure_count SMALLINT NOT NULL DEFAULT 0, window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), locked_until TIMESTAMPTZ, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW())');
      await db.query('CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_updated ON auth_login_attempts (updated_at)');
      await db.query('CREATE TABLE IF NOT EXISTS auth_device_signups (device_hash CHAR(64) PRIMARY KEY, firebase_uid TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW())');

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
      await db.query(`CREATE TABLE IF NOT EXISTS points_transfer_requests (
        sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        idempotency_key TEXT NOT NULL,
        receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount INT NOT NULL CHECK (amount > 0),
        response JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (sender_id, idempotency_key),
        CHECK (char_length(idempotency_key) BETWEEN 16 AND 128)
      )`);
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS campus_id TEXT UNIQUE`);
      await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS deal_code TEXT`);
      await db.query(`CREATE UNIQUE INDEX IF NOT EXISTS uq_users_deal_code ON users (deal_code) WHERE deal_code IS NOT NULL`);
      await db.query(`CREATE TABLE IF NOT EXISTS reports (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        target_type TEXT NOT NULL CHECK (target_type IN ('post','user','product','note')),
        target_id UUID NOT NULL,
        reported_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','resolved')),
        resolution TEXT,
        resolved_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);
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
      await db.query(`CREATE TABLE IF NOT EXISTS deal_redemptions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (deal_id, user_id)
      )`);

      // Events table
      await db.query(`CREATE TABLE IF NOT EXISTS events (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        place TEXT NOT NULL,
        time_date TEXT NOT NULL,
        registration_mode TEXT NOT NULL DEFAULT 'external',
        registration_link TEXT,
        picture_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW())`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_events_created_at ON events (created_at DESC)`);
      await db.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_mode TEXT NOT NULL DEFAULT 'external'`);
      await db.query(`ALTER TABLE events ALTER COLUMN registration_link DROP NOT NULL`);
      await db.query(`DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'events_registration_mode_check'
            AND conrelid = 'events'::regclass
        ) THEN
          ALTER TABLE events ADD CONSTRAINT events_registration_mode_check
            CHECK (registration_mode IN ('external', 'internal'));
        END IF;
      END $$`);
      await db.query(`CREATE TABLE IF NOT EXISTS event_registrations (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (event_id, user_id)
      )`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_event_registrations_user_event
        ON event_registrations (user_id, event_id)`);

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
        firebase_uid TEXT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        college_name TEXT NOT NULL,
        subject TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      // Remove the legacy plaintext password column. Approved requests can be
      // linked to their existing user; old pending requests must be resubmitted.
      await db.query('ALTER TABLE faculty_requests ADD COLUMN IF NOT EXISTS firebase_uid TEXT');
      await db.query(`UPDATE faculty_requests fr
        SET firebase_uid = u.firebase_uid
        FROM users u
        WHERE u.role = 'faculty'
          AND fr.firebase_uid IS NULL
          AND LOWER(fr.email) = LOWER(u.email)`);
      await db.query(`UPDATE faculty_requests SET status = 'rejected'
        WHERE status = 'pending' AND firebase_uid IS NULL`);
      await db.query('ALTER TABLE faculty_requests DROP COLUMN IF EXISTS password');
      await db.query(`CREATE UNIQUE INDEX IF NOT EXISTS idx_faculty_requests_firebase_uid
        ON faculty_requests (firebase_uid) WHERE firebase_uid IS NOT NULL`);

      // Sync approved faculty role
      await db.query(`UPDATE users u
        SET role = 'faculty'
        FROM faculty_requests fr
        WHERE fr.status = 'approved'
          AND (LOWER(u.email) = LOWER(fr.email) OR (u.firebase_uid IS NOT NULL AND u.firebase_uid = fr.firebase_uid))
          AND (u.role IS NULL OR u.role != 'faculty')`);

      // Quizzes
      await db.query(`CREATE TABLE IF NOT EXISTS quizzes (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        faculty_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        pin TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','waiting','live','ended')),
        mode TEXT NOT NULL DEFAULT 'live' CHECK (mode IN ('live','paper')),
        duration_minutes INT NOT NULL DEFAULT 60 CHECK (duration_minutes > 0),
        settings JSONB NOT NULL DEFAULT '{}'::jsonb,
        current_question INT DEFAULT 0,
        question_started_at TIMESTAMPTZ,
        ended_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query('ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS question_started_at TIMESTAMPTZ');
      await db.query("ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'live'");
      await db.query('ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS duration_minutes INT NOT NULL DEFAULT 60');
      await db.query("ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb");

      // Quiz questions
      await db.query(`CREATE TABLE IF NOT EXISTS quiz_questions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        question_text TEXT NOT NULL,
        image_url TEXT,
        options JSONB NOT NULL,
        marks INT NOT NULL DEFAULT 1 CHECK (marks > 0),
        order_index INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query('ALTER TABLE quiz_questions ADD COLUMN IF NOT EXISTS marks INT NOT NULL DEFAULT 1');

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

      await db.query(`CREATE TABLE IF NOT EXISTS quiz_submissions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        answers JSONB NOT NULL DEFAULT '[]'::jsonb,
        total_score INT NOT NULL DEFAULT 0,
        submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (quiz_id, user_id)
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS quiz_test_attempts (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        answers JSONB NOT NULL DEFAULT '{}'::jsonb,
        UNIQUE (quiz_id, user_id)
      )`);
      await db.query("ALTER TABLE quiz_test_attempts ADD COLUMN IF NOT EXISTS answers JSONB NOT NULL DEFAULT '{}'::jsonb");
      await db.query(`CREATE TABLE IF NOT EXISTS quiz_test_events (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        event_type TEXT NOT NULL CHECK (event_type IN ('tab_switch')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);

      // User-owned resume documents and short-lived mobile-to-web editor links.
      await db.query(`CREATE TABLE IF NOT EXISTS resume_documents (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
        title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
        template_id TEXT NOT NULL,
        content JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_resume_documents_owner_updated
        ON resume_documents (firebase_uid, updated_at DESC)`);
      await db.query(`CREATE TABLE IF NOT EXISTS resume_browser_handoffs (
        code_hash CHAR(64) PRIMARY KEY,
        firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_resume_handoffs_expiry
        ON resume_browser_handoffs (expires_at)`);

      // Temporary account recovery state. Passwords remain managed by Firebase Auth.
      await db.query(`CREATE TABLE IF NOT EXISTS password_reset_otps (
        firebase_uid TEXT PRIMARY KEY REFERENCES users(firebase_uid) ON DELETE CASCADE,
        otp_hash TEXT,
        reset_token_hash CHAR(64) UNIQUE,
        expires_at TIMESTAMPTZ NOT NULL,
        attempts SMALLINT NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
        sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        requests_in_window SMALLINT NOT NULL DEFAULT 1 CHECK (requests_in_window BETWEEN 1 AND 3),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_password_reset_otps_expiry
        ON password_reset_otps (expires_at)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email))`);

      // Indexes
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quizzes_status ON quizzes (status, created_at DESC)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quizzes_faculty ON quizzes (faculty_id)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions (quiz_id, order_index)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_participants_quiz ON quiz_participants (quiz_id, total_score DESC)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_submissions_quiz ON quiz_submissions (quiz_id, total_score DESC, submitted_at ASC)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_test_attempts_quiz ON quiz_test_attempts (quiz_id, started_at)`);
      await db.query(`CREATE INDEX IF NOT EXISTS idx_quiz_test_events_attempt ON quiz_test_events (quiz_id, user_id, created_at DESC)`);

      // Alarm remote wallpapers
      await db.query(`CREATE TABLE IF NOT EXISTS alarm_wallpapers (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        type TEXT NOT NULL CHECK (type IN ('image', 'animated', 'video')),
        label TEXT NOT NULL,
        url TEXT NOT NULL,
        thumbnail_url TEXT,
        sort_order INT DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_stores (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        firebase_uid TEXT NOT NULL UNIQUE REFERENCES users(firebase_uid) ON DELETE CASCADE,
        owner_name TEXT,
        restaurant_name TEXT NOT NULL DEFAULT 'Naya restaurant',
        mobile_number TEXT,
        email TEXT,
        city TEXT,
        state TEXT,
        upi_id TEXT,
        gst_percent NUMERIC(5,2) DEFAULT 5,
        tables_count INT DEFAULT 8,
        bill_prefix TEXT DEFAULT 'POS',
        theme TEXT DEFAULT 'Auto',
        notifications_enabled BOOLEAN DEFAULT true,
        enabled_modules JSONB DEFAULT '{"inventory": true, "udhaar": true, "staff": true, "redeem": true, "reports": true}'::jsonb,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_food_items (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Main',
        price NUMERIC(10,2) NOT NULL DEFAULT 0,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_bills (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        bill_number TEXT NOT NULL,
        table_number TEXT NOT NULL,
        items JSONB NOT NULL DEFAULT '[]'::jsonb,
        subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
        gst_percent NUMERIC(5,2) DEFAULT 5,
        gst_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        payment_mode TEXT NOT NULL DEFAULT 'Cash',
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_inventory (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        item_name TEXT NOT NULL,
        quantity NUMERIC(10,2) NOT NULL DEFAULT 1,
        amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        vendor TEXT,
        purchase_date DATE DEFAULT CURRENT_DATE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_udhaar (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        customer_name TEXT NOT NULL,
        amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        type TEXT NOT NULL CHECK (type IN ('given', 'repaid')),
        transaction_date DATE DEFAULT CURRENT_DATE,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_staff (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        post TEXT NOT NULL,
        salary NUMERIC(10,2) NOT NULL DEFAULT 0,
        joining_date DATE DEFAULT CURRENT_DATE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);
      await db.query(`CREATE TABLE IF NOT EXISTS enterprise_staff_advances (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        staff_id UUID NOT NULL REFERENCES enterprise_staff(id) ON DELETE CASCADE,
        store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
        amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        advance_date DATE DEFAULT CURRENT_DATE,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )`);

      await db.query(`ALTER TABLE deals ADD COLUMN IF NOT EXISTS city TEXT;`);
      await db.query(`ALTER TABLE deals ADD COLUMN IF NOT EXISTS state TEXT;`);

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
