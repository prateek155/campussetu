-- backend/schema.sql
-- CampusSetu PostgreSQL Schema (Phase 1)
-- Run once: psql -U postgres -d campussetu -f schema.sql

-- ── Extensions ────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for ILIKE trigram index

-- Login cooldown state is keyed by a SHA-256 of normalized email + client IP.
CREATE TABLE IF NOT EXISTS auth_login_attempts (
  attempt_key CHAR(64) PRIMARY KEY,
  failure_count SMALLINT NOT NULL DEFAULT 0,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  locked_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_updated ON auth_login_attempts (updated_at);

-- One new account signup per persisted app installation identifier.
-- Store only a server-side hash, never the installation identifier.
CREATE TABLE IF NOT EXISTS auth_device_signups (
  device_hash CHAR(64) PRIMARY KEY,
  firebase_uid TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_uid     TEXT UNIQUE NOT NULL,
  email            TEXT UNIQUE NOT NULL,
  name             TEXT NOT NULL DEFAULT '',
  photo_url        TEXT,
  college          TEXT,
  state            TEXT,
  city             TEXT,
  course           TEXT,       -- B.Tech, M.Tech, MBA, etc.
  branch           TEXT,       -- CS, Mechanical, etc.
  year_of_study    SMALLINT CHECK (year_of_study BETWEEN 1 AND 7),
  bio              TEXT CHECK (char_length(bio) <= 300),
  skills           TEXT[]      DEFAULT '{}',
  profile_complete BOOLEAN     DEFAULT false,
  campus_id        TEXT UNIQUE,
  deal_code        TEXT,
  is_verified      BOOLEAN     DEFAULT false,
  is_premium       BOOLEAN     DEFAULT false,
  is_banned        BOOLEAN     DEFAULT false,
  is_admin         BOOLEAN     DEFAULT false,
  is_enterprise    BOOLEAN     DEFAULT false,
  is_shopkeeper    BOOLEAN     DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS deal_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_deal_code ON users (deal_code) WHERE deal_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_state_city   ON users (state, city);
CREATE INDEX IF NOT EXISTS idx_users_skills        ON users USING GIN (skills);

-- ── RESUME BUILDER ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS resume_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
  template_id TEXT NOT NULL,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_resume_documents_owner_updated
  ON resume_documents (firebase_uid, updated_at DESC);

CREATE TABLE IF NOT EXISTS resume_browser_handoffs (
  code_hash CHAR(64) PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_resume_handoffs_expiry
  ON resume_browser_handoffs (expires_at);

-- Short-lived OTP and one-time reset token state; password credentials remain in Firebase Auth.
CREATE TABLE IF NOT EXISTS password_reset_otps (
  firebase_uid        TEXT PRIMARY KEY REFERENCES users(firebase_uid) ON DELETE CASCADE,
  otp_hash            TEXT,
  reset_token_hash    CHAR(64) UNIQUE,
  expires_at          TIMESTAMPTZ NOT NULL,
  attempts            SMALLINT NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
  sent_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  window_started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  requests_in_window  SMALLINT NOT NULL DEFAULT 1 CHECK (requests_in_window BETWEEN 1 AND 3),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_password_reset_otps_expiry
  ON password_reset_otps (expires_at);

-- ─────────────────────────────────────────────────────────
-- CONNECTIONS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS connections (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (requester_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_receiver ON connections (receiver_id, status);

-- ─────────────────────────────────────────────────────────
-- POSTS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content     TEXT NOT NULL CHECK (char_length(content) <= 2000),
  image_url   TEXT,
  is_deleted  BOOLEAN     DEFAULT false,
  is_pinned   BOOLEAN     DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_posts_author     ON posts (author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts (created_at DESC);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_comments (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id    UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    TEXT NOT NULL CHECK (char_length(content) <= 500),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- TSHARE
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tshares (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code           TEXT UNIQUE NOT NULL,
  content        TEXT NOT NULL,
  language       TEXT DEFAULT 'text',
  uploader_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  retrieve_count INT  DEFAULT 0,
  expires_at     TIMESTAMPTZ NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- CREATE INDEX IF NOT EXISTS idx_tshares_code ON tshares (code) WHERE expires_at > NOW();

-- ─────────────────────────────────────────────────────────
-- NOTES
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title          TEXT NOT NULL,
  subject        TEXT NOT NULL,
  file_url       TEXT NOT NULL,
  file_size_mb   NUMERIC(6,2),
  uploader_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  download_count INT  DEFAULT 0,
  is_approved    BOOLEAN DEFAULT false,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notes_subject     ON notes (subject);
CREATE INDEX IF NOT EXISTS idx_notes_approved    ON notes (is_approved, download_count DESC);

-- ─────────────────────────────────────────────────────────
-- JOBS / OPPORTUNITIES
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS jobs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL,
  company     TEXT NOT NULL,
  description TEXT,
  type        TEXT CHECK (type IN ('Internship','Full-Time','Part-Time','Freelance','Research')),
  state       TEXT,
  city        TEXT,
  is_remote   BOOLEAN DEFAULT false,
  apply_url   TEXT,
  deadline    DATE,
  poster_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_approved BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jobs_type_state ON jobs (type, state, is_approved);

-- ─────────────────────────────────────────────────────────
-- PRODUCTS (Marketplace)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL,
  description TEXT,
  price       NUMERIC(10,2) NOT NULL,
  category    TEXT NOT NULL,
  image_url   TEXT,
  seller_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      TEXT DEFAULT 'active' CHECK (status IN ('active','sold','removed')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products (category, status);

-- ─────────────────────────────────────────────────────────
-- REPORTS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type       TEXT NOT NULL CHECK (target_type IN ('post','user','product','note')),
  target_id         UUID NOT NULL,
  reported_user_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  reason            TEXT NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','resolved')),
  resolution        TEXT,
  resolved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- POINTS LEDGER
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS points_ledger (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount      INT NOT NULL,
  reason      TEXT NOT NULL, -- 'note_upload', 'connection_made', etc.
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_points_user ON points_ledger (user_id);

CREATE TABLE IF NOT EXISTS points_transfer_requests (
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  idempotency_key TEXT NOT NULL,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INT NOT NULL CHECK (amount > 0),
  response JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (sender_id, idempotency_key),
  CHECK (char_length(idempotency_key) BETWEEN 16 AND 128)
);

-- ─────────────────────────────────────────────────────────
-- STARTUPS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS startups (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  tagline     TEXT NOT NULL,
  description TEXT,
  sector      TEXT,
  stage       TEXT CHECK (stage IN ('Ideation','MVP','Pre-Revenue','Revenue','Scaling')),
  founder_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  team_size   INT DEFAULT 1,
  looking_for INT DEFAULT 0,
  is_approved BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- STARTUP TEAM MEMBERS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS startup_members (
  startup_id UUID NOT NULL REFERENCES startups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       TEXT DEFAULT 'Member',
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (startup_id, user_id)
);

-- ─────────────────────────────────────────────────────────
-- HELPING HAND (Paid / Points tasks)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS helping_tasks (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  description TEXT NOT NULL CHECK (char_length(description) BETWEEN 5 AND 2000),
  image_url   TEXT,
  type        TEXT NOT NULL CHECK (type IN ('paid','points')),
  amount      NUMERIC(10,2),
  points      INT,
  deadline    DATE,
  poster_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','assigned','completed','cancelled','on_hold')),
  assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  expires_at  TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
  CONSTRAINT helping_paid_check CHECK (
    (type = 'paid' AND amount IS NOT NULL AND amount > 0) OR
    (type = 'points' AND points IS NOT NULL AND points > 0)
  )
);

CREATE INDEX IF NOT EXISTS idx_helping_type_status ON helping_tasks (type, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_helping_poster ON helping_tasks (poster_id);

CREATE TABLE IF NOT EXISTS helping_applications (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id      UUID NOT NULL REFERENCES helping_tasks(id) ON DELETE CASCADE,
  applicant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'applied' CHECK (status IN ('applied','accepted','rejected')),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (task_id, applicant_id)
);

CREATE INDEX IF NOT EXISTS idx_helping_apps_task ON helping_applications (task_id, status);

-- ── Migration for existing DBs: 7-day auto-hold + delete support ──
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days';
UPDATE helping_tasks SET expires_at = created_at + INTERVAL '7 days' WHERE expires_at IS NULL;
ALTER TABLE IF EXISTS helping_tasks DROP CONSTRAINT IF EXISTS helping_tasks_status_check;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'helping_tasks_status_hold_check') THEN
    ALTER TABLE helping_tasks ADD CONSTRAINT helping_tasks_status_hold_check CHECK (status IN ('open','assigned','completed','cancelled','on_hold'));
  END IF;
END $$;
UPDATE helping_tasks SET status = 'on_hold' WHERE status = 'open' AND COALESCE(expires_at, created_at + INTERVAL '7 days') <= NOW();
CREATE INDEX IF NOT EXISTS idx_helping_expires ON helping_tasks (expires_at, status);

-- ── Dual-Confirmation Task Completion ──
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS poster_completed BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS assignee_completed BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS poster_completed_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS assignee_completed_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS helping_tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- ── Migration: Campus ID for points transfer + identity card ──
ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS campus_id TEXT UNIQUE;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_campus_id ON users (campus_id);

-- ── Anti-abuse: signup bonus once per user, like-milestone once per level ──
CREATE UNIQUE INDEX IF NOT EXISTS uq_points_signup_once ON points_ledger (user_id) WHERE reason = 'signup_bonus';
CREATE UNIQUE INDEX IF NOT EXISTS uq_points_milestone_once ON points_ledger (user_id, reason) WHERE reason LIKE 'post_like_milestone:%';

-- ─────────────────────────────────────────────────────────
-- DEALS / OFFERS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  discount_code TEXT,
  banner_url TEXT,
  city TEXT,
  state TEXT,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE deals ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE deals ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS deal_redemptions (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  deal_id      UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  redeemed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (deal_id, user_id)
);

-- ─────────────────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  place TEXT NOT NULL,
  time_date TEXT NOT NULL,
  registration_mode TEXT NOT NULL DEFAULT 'external',
  registration_link TEXT,
  picture_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events (created_at DESC);

-- Existing events stay on the original external-link flow.
ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_mode TEXT NOT NULL DEFAULT 'external';
ALTER TABLE events ALTER COLUMN registration_link DROP NOT NULL;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'events_registration_mode_check'
      AND conrelid = 'events'::regclass
  ) THEN
    ALTER TABLE events ADD CONSTRAINT events_registration_mode_check
      CHECK (registration_mode IN ('external', 'internal'));
  END IF;
END $$;
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_event_code ON events (event_code);
UPDATE events SET event_code = 'EVT-' || UPPER(SUBSTRING(REPLACE(id::text, '-', ''), 1, 6)) WHERE event_code IS NULL;

ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_access_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_id TEXT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_password_hash TEXT;
CREATE INDEX IF NOT EXISTS idx_events_organizer_id ON events (LOWER(organizer_id)) WHERE organizer_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'confirmed',
  custom_name TEXT,
  custom_email TEXT,
  phone TEXT,
  custom_college TEXT,
  custom_branch TEXT,
  notes TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (event_id, user_id)
);
ALTER TABLE event_registrations ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'confirmed';
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS custom_name TEXT;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS custom_email TEXT;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS custom_college TEXT;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS custom_branch TEXT;
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS notes TEXT;
CREATE INDEX IF NOT EXISTS idx_event_registrations_user_event
  ON event_registrations (user_id, event_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_event_reg_guest_email
  ON event_registrations (event_id, LOWER(custom_email))
  WHERE user_id IS NULL AND custom_email IS NOT NULL;

CREATE TABLE IF NOT EXISTS travel_rides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  vehicle_type TEXT NOT NULL,
  destination TEXT NOT NULL,
  time_date TEXT NOT NULL,
  contact_number TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────
-- FLATMATES
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS flatmates (
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
);

-- ─────────────────────────────────────────────────────────
-- FACULTY & QUIZ SYSTEM
-- ─────────────────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'student';
ALTER TABLE users ADD COLUMN IF NOT EXISTS college_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS subject TEXT;

CREATE TABLE IF NOT EXISTS faculty_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  firebase_uid TEXT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  college_name TEXT NOT NULL,
  subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate legacy requests without retaining their plaintext passwords.
ALTER TABLE faculty_requests ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
UPDATE faculty_requests fr
SET firebase_uid = u.firebase_uid
FROM users u
WHERE u.role = 'faculty'
  AND fr.firebase_uid IS NULL
  AND LOWER(fr.email) = LOWER(u.email);
UPDATE faculty_requests SET status = 'rejected'
WHERE status = 'pending' AND firebase_uid IS NULL;
ALTER TABLE faculty_requests DROP COLUMN IF EXISTS password;
CREATE UNIQUE INDEX IF NOT EXISTS idx_faculty_requests_firebase_uid
  ON faculty_requests (firebase_uid) WHERE firebase_uid IS NOT NULL;

CREATE TABLE IF NOT EXISTS quizzes (
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
);
ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS question_started_at TIMESTAMPTZ;
ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'live';
ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS duration_minutes INT NOT NULL DEFAULT 60;
ALTER TABLE quizzes ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS quiz_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  image_url TEXT,
  options JSONB NOT NULL,
  marks INT NOT NULL DEFAULT 1 CHECK (marks > 0),
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE quiz_questions ADD COLUMN IF NOT EXISTS marks INT NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS quiz_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_score INT DEFAULT 0,
  answers JSONB DEFAULT '[]',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(quiz_id, user_id)
);

CREATE TABLE IF NOT EXISTS quiz_submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  answers JSONB NOT NULL DEFAULT '[]'::jsonb,
  total_score INT NOT NULL DEFAULT 0,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (quiz_id, user_id)
);

CREATE TABLE IF NOT EXISTS quiz_test_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (quiz_id, user_id)
);
ALTER TABLE quiz_test_attempts ADD COLUMN IF NOT EXISTS answers JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS quiz_test_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('tab_switch')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quizzes_status ON quizzes (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quizzes_faculty ON quizzes (faculty_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions (quiz_id, order_index);
CREATE INDEX IF NOT EXISTS idx_quiz_participants_quiz ON quiz_participants (quiz_id, total_score DESC);
CREATE INDEX IF NOT EXISTS idx_quiz_submissions_quiz ON quiz_submissions (quiz_id, total_score DESC, submitted_at ASC);
CREATE INDEX IF NOT EXISTS idx_quiz_test_attempts_quiz ON quiz_test_attempts (quiz_id, started_at);
CREATE INDEX IF NOT EXISTS idx_quiz_test_events_attempt ON quiz_test_events (quiz_id, user_id, created_at DESC);

-- ── ENTERPRISE POS & RESTAURANT BILLING ────────────────────
CREATE TABLE IF NOT EXISTS enterprise_stores (
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
);

CREATE TABLE IF NOT EXISTS enterprise_food_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Main',
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ent_food_items_store ON enterprise_food_items (store_id, category);

CREATE TABLE IF NOT EXISTS enterprise_bills (
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
);
CREATE INDEX IF NOT EXISTS idx_ent_bills_store_date ON enterprise_bills (store_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ent_bills_store_bill_num ON enterprise_bills (store_id, bill_number);

CREATE TABLE IF NOT EXISTS enterprise_inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  quantity NUMERIC(10,2) NOT NULL DEFAULT 1,
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  vendor TEXT,
  purchase_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ent_inventory_store ON enterprise_inventory (store_id);

CREATE TABLE IF NOT EXISTS enterprise_udhaar (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  type TEXT NOT NULL CHECK (type IN ('given', 'repaid')),
  transaction_date DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ent_udhaar_store ON enterprise_udhaar (store_id, customer_name);

CREATE TABLE IF NOT EXISTS enterprise_staff (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  post TEXT NOT NULL,
  salary NUMERIC(10,2) NOT NULL DEFAULT 0,
  joining_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ent_staff_store ON enterprise_staff (store_id);

CREATE TABLE IF NOT EXISTS enterprise_staff_advances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_id UUID NOT NULL REFERENCES enterprise_staff(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES enterprise_stores(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  advance_date DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ent_staff_advances_staff ON enterprise_staff_advances (staff_id);




-- ─────────────────────────────────────────────────────────
-- ALARM WALLPAPERS (Live, Animated Rive, Videos)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alarm_wallpapers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL CHECK (type IN ('image', 'animated', 'video')),
  label TEXT NOT NULL,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
