// backend/src/controllers/users.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const cache = require('../config/redis');


const CAMPUS_ID_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function genCampusId() {
  let s = 'CS-';
  for (let i = 0; i < 6; i++) s += CAMPUS_ID_CHARS[Math.floor(Math.random() * CAMPUS_ID_CHARS.length)];
  return s;
}

// Ensures user has a unique campus_id (for identity card + points transfer)
async function ensureCampusId(userId) {
  const { rows } = await db.query('SELECT campus_id FROM users WHERE id = $1', [userId]);
  if (!rows.length || rows[0].campus_id) return rows.length ? rows[0].campus_id : null;
  for (let i = 0; i < 8; i++) {
    try {
      const cid = genCampusId();
      const { rows: u } = await db.query('UPDATE users SET campus_id = $1 WHERE id = $2 AND campus_id IS NULL RETURNING campus_id', [cid, userId]);
      if (u.length) return u[0].campus_id;
      const { rows: cur } = await db.query('SELECT campus_id FROM users WHERE id = $1', [userId]);
      if (cur.length && cur[0].campus_id) return cur[0].campus_id;
    } catch (e) { if (e.code !== '23505') throw e; }
  }
  return null;
}

function genDealCode(name) {
  let initials = 'XX';
  if (name) {
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) {
      initials = (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (parts[0].length >= 1) {
      initials = parts[0].substring(0, 2).toUpperCase().padEnd(2, 'X');
    }
  }
  const digits = Math.floor(1000 + Math.random() * 9000);
  return `${initials}${digits}`;
}

async function ensureDealCode(userId, name) {
  const { rows } = await db.query('SELECT deal_code FROM users WHERE id = $1', [userId]);
  if (!rows.length || rows[0].deal_code) return;
  for (let i = 0; i < 8; i++) {
    try {
      const code = genDealCode(name);
      const { rows: u } = await db.query('UPDATE users SET deal_code = $1 WHERE id = $2 AND deal_code IS NULL RETURNING deal_code', [code, userId]);
      if (u.length) return;
    } catch (e) { if (e.code !== '23505') throw e; }
  }
}

// Awards 25 signup bonus once (unique index makes concurrent calls safe)
async function ensureSignupBonus(userId) {
  await db.query(
    `INSERT INTO points_ledger (id, user_id, amount, reason)
     VALUES ($1, $2, 25, 'signup_bonus') ON CONFLICT DO NOTHING`,
    [uuidv4(), userId]
  );
}

function parseStrictAmount(v) {
  const s = String(v ?? '').trim();
  const n = parseInt(s, 10);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}

// ── GET /users/:id ──────────────────────────────────────
exports.getUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      `SELECT u.*,
        (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count,
        (SELECT COUNT(*) FROM notes n WHERE n.uploader_id = u.id AND n.is_approved = true) AS notes_count,
        (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points
       FROM users u WHERE u.id = $1`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    await ensureCampusId(id);
    await ensureDealCode(id, rows[0].name);
    const { rows: fresh } = await db.query(
      `SELECT u.*,
        (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count,
        (SELECT COUNT(*) FROM notes n WHERE n.uploader_id = u.id AND n.is_approved = true) AS notes_count,
        (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points
       FROM users u WHERE u.id = $1`,
      [id]
    );
    res.json(fresh[0] || rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// ── GET /users/me ────────────────────────────────────────
exports.getMe = async (req, res) => {
  try {
    const cacheKey = `user:me:${req.user.uid}`;
    const cached = await cache.getCache(cacheKey);
    if (cached) {
      try { return res.json(JSON.parse(cached)); } catch (_) {}
    }

    const { rows } = await db.query(
      `SELECT u.*,
        (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count,
        (SELECT COUNT(*) FROM notes n WHERE n.uploader_id = u.id AND n.is_approved = true) AS notes_count,
        (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points
       FROM users u WHERE u.firebase_uid = $1`,
      [req.user.uid]
    );
    if (rows.length) {
      await ensureCampusId(rows[0].id);
      await ensureDealCode(rows[0].id, rows[0].name);
      await ensureSignupBonus(rows[0].id);
      const { rows: fresh } = await db.query(
        `SELECT u.*,
          (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count,
          (SELECT COUNT(*) FROM notes n WHERE n.uploader_id = u.id AND n.is_approved = true) AS notes_count,
          (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points
         FROM users u WHERE u.firebase_uid = $1`,
        [req.user.uid]
      );
      const userObj = fresh[0] || rows[0];
      await cache.setCache(cacheKey, JSON.stringify(userObj), 120); // 2 min
      return res.json(userObj);
    }


    const email = req.user.email || '';
    const name = req.user.name || req.user.displayName || email.split('@')[0] || 'User';
    const photo = req.user.picture || req.user.photoURL || req.user.photo_url || null;

    const { rows: created } = await db.query(
      `INSERT INTO users (firebase_uid, email, name, photo_url)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (firebase_uid) DO UPDATE SET email = EXCLUDED.email RETURNING *`,
      [req.user.uid, email, name, photo]
    );
    await ensureCampusId(created[0].id);
    await ensureDealCode(created[0].id, created[0].name);
    await ensureSignupBonus(created[0].id);
    const { rows: withCounts } = await db.query(
      `SELECT u.*,
        (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count,
        (SELECT COUNT(*) FROM notes n WHERE n.uploader_id = u.id AND n.is_approved = true) AS notes_count,
        (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points
       FROM users u WHERE u.id = $1`,
      [created[0].id]
    );
    return res.json(withCounts[0] || created[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /users/:id/profile ──────────────────────────────
exports.updateProfile = async (req, res) => {
  try {
    const firebaseUid = req.user.uid;

    // Verify that the authenticated Firebase user exists
    const { rows: user } = await db.query(
      'SELECT id, firebase_uid FROM users WHERE firebase_uid = $1',
      [firebaseUid]
    );

    if (!user.length) {
      return res.status(404).json({ error: 'User not found' });
    }

    const {
      name,
      college,
      state,
      city,
      course,
      branch,
      year_of_study,
      bio,
      skills,
      profile_complete,
      photo_url,
    } = req.body;

    const { rows } = await db.query(
      `UPDATE users SET
         name = COALESCE($1, name),
         college = COALESCE($2, college),
         state = COALESCE($3, state),
         city = COALESCE($4, city),
         course = COALESCE($5, course),
         branch = COALESCE($6, branch),
         year_of_study = COALESCE($7, year_of_study),
         bio = COALESCE($8, bio),
         skills = COALESCE($9, skills),
         profile_complete = COALESCE($10, profile_complete),
         photo_url = COALESCE($11, photo_url),
         updated_at = NOW()
       WHERE firebase_uid = $12
       RETURNING *`,
      [
        name,
        college,
        state,
        city,
        course,
        branch,
        year_of_study,
        bio,
        skills,
        profile_complete,
        photo_url,
        firebaseUid,
      ]
    );

    await cache.delCache(`user:me:${firebaseUid}`);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};


// ── GET /users/by-campus/:campusId ──────────────────────
// Public mini-profile to verify receiver before points transfer
exports.getByCampusId = async (req, res) => {
  try {
    const cid = (req.params.campusId || '').toString().trim().toUpperCase();
    if (!cid) return res.status(400).json({ error: 'campusId required' });
    const { rows } = await db.query(
      `SELECT u.id, u.name, u.photo_url, u.college, u.city, u.state, u.campus_id
       FROM users u WHERE UPPER(u.campus_id) = $1`,
      [cid]
    );
    if (!rows.length) return res.status(404).json({ error: 'Student not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// ── POST /users/transfer {to_campus_id, amount} ──────────
// Student → student points transfer (atomic, balance-checked)
exports.transferPoints = async (req, res) => {
  try {
    const toCampusId = (req.body.to_campus_id || '').toString().trim().toUpperCase();
    const amount = parseStrictAmount(req.body.amount);
    if (!toCampusId) return res.status(400).json({ error: 'to_campus_id required' });
    if (!amount) return res.status(400).json({ error: 'valid amount required' });
    if (amount > 100000) return res.status(400).json({ error: 'amount too large' });

    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });
    const senderId = me[0].id;

    const { rows: recv } = await db.query('SELECT id, name FROM users WHERE UPPER(campus_id) = $1', [toCampusId]);
    if (!recv.length) return res.status(404).json({ error: 'Receiver not found' });
    if (recv[0].id === senderId) return res.status(400).json({ error: 'Cannot transfer to yourself' });

    const client = await db.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [senderId]);
      const { rows: b } = await client.query('SELECT COALESCE(SUM(amount),0)::int AS bal FROM points_ledger WHERE user_id = $1', [senderId]);
      if (b[0].bal < amount) { await client.query('ROLLBACK'); return res.status(400).json({ error: `Insufficient points. Balance: ${b[0].bal}` }); }
      await client.query(`INSERT INTO points_ledger (id, user_id, amount, reason) VALUES ($1,$2,$3,$4)`, [uuidv4(), senderId, -amount, `points_transfer_sent:${recv[0].id}`]);
      await client.query(`INSERT INTO points_ledger (id, user_id, amount, reason) VALUES ($1,$2,$3,$4)`, [uuidv4(), recv[0].id, amount, `points_transfer_received:${senderId}`]);
      const { rows: nb } = await client.query('SELECT COALESCE(SUM(amount),0)::int AS bal FROM points_ledger WHERE user_id = $1', [senderId]);
      await client.query('COMMIT');
      await cache.delPattern('user:me:*');
      res.json({ sent: amount, to: recv[0].name, new_balance: nb[0].bal });
    } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// ── POST /users/:id/photo ──────────────────────────────
exports.uploadPhoto = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file' });
    const firebaseUid = req.user.uid;
    const fileUrl = `/uploads/${req.file.filename}`;
    const { rows } = await db.query(
      `UPDATE users SET photo_url = $1, updated_at = NOW() WHERE firebase_uid = $2 RETURNING *`,
      [fileUrl, firebaseUid]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    await cache.delCache(`user:me:${firebaseUid}`);
    const host = `${req.protocol}://${req.get('host')}`;
    const fullUrl = `${host}${fileUrl}`;
    res.json({ ...rows[0], photo_url: fullUrl, file_url: fullUrl });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// ── GET /connect/discover ────────────────────────────────
exports.discoverStudents = async (req, res) => {
  try {
    const { state, city, branch, year, skill, q, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const conditions = ['u.profile_complete = true', 'u.firebase_uid != $1'];
    const params = [req.user.uid];

    if (state) { params.push(state); conditions.push(`u.state = $${params.length}`); }
    if (city) { params.push(city); conditions.push(`u.city = $${params.length}`); }
    if (branch) { params.push(`%${branch}%`); conditions.push(`u.branch ILIKE $${params.length}`); }
    if (year) { params.push(parseInt(year)); conditions.push(`u.year_of_study = $${params.length}`); }
    if (skill) { params.push(skill); conditions.push(`$${params.length} = ANY(u.skills)`); }
    if (q) {
      params.push(`%${q}%`);
      conditions.push(`(u.name ILIKE $${params.length} OR u.college ILIKE $${params.length} OR u.branch ILIKE $${params.length})`);
    }

    // Exclude users already connected or pending
    conditions.push(`u.id NOT IN (
      SELECT requester_id FROM connections WHERE receiver_id = (SELECT id FROM users WHERE firebase_uid = $1)
      UNION
      SELECT receiver_id FROM connections WHERE requester_id = (SELECT id FROM users WHERE firebase_uid = $1)
    )`);

    params.push(parseInt(limit), parseInt(offset));
    const limitIndex = params.length - 1;
    const offsetIndex = params.length;

    const { rows } = await db.query(
      `SELECT u.id, u.name, u.college, u.city, u.state, u.branch, u.year_of_study,
              u.skills, u.photo_url, u.is_verified, u.is_premium, u.campus_id,
              (SELECT COALESCE(SUM(amount), 0) FROM points_ledger pl WHERE pl.user_id = u.id) AS points,
              (SELECT COUNT(*) FROM connections c WHERE (c.requester_id = u.id OR c.receiver_id = u.id) AND c.status = 'accepted') AS connections_count
       FROM users u
       WHERE ${conditions.join(' AND ')}
       ORDER BY u.is_verified DESC, u.created_at DESC
       LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
      params
    );
    res.json({ data: rows, page: parseInt(page) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};exports.getHomeCounts = async (req, res) => {
  try {
    const cacheKey = 'home:counts';
    const cached = await cache.getCache(cacheKey);
    if (cached) {
      try { return res.json(JSON.parse(cached)); } catch (_) {}
    }

    const deals = await db.query('SELECT COUNT(*) FROM deals');
    const events = await db.query('SELECT COUNT(*) FROM events');
    const travels = await db.query("SELECT COUNT(*) FROM travel_rides WHERE status = 'active'");
    const tasks = await db.query("SELECT COUNT(*) FROM helping_tasks WHERE status = 'open'");
    const flatmates = await db.query("SELECT COUNT(*) FROM flatmates WHERE status = 'active'");
    const liveQuizzes = await db.query("SELECT COUNT(*) FROM quizzes WHERE status IN ('waiting', 'live')");

    const result = {
      deals: parseInt(deals.rows[0].count),
      events: parseInt(events.rows[0].count),
      travels: parseInt(travels.rows[0].count),
      flatmates: parseInt(flatmates.rows[0].count),
      tasks: parseInt(tasks.rows[0].count),
      live_quizzes: parseInt(liveQuizzes.rows[0].count),
    };

    await cache.setCache(cacheKey, JSON.stringify(result), 30); // 30 sec
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


