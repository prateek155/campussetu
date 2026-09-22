// backend/src/controllers/admin.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');
const activityLog = require('../middleware/activityLogger');

// ── POST /admin/points {user_id | campus_id, amount, reason?} ──
// Admin can grant (or revoke with negative amount) any points
exports.grantPoints = async (req, res) => {
  try {
    const { user_id, campus_id, amount, reason } = req.body;
    const pts = parseInt(amount);
    if (!pts || pts === 0) return res.status(400).json({ error: 'valid non-zero amount required' });
    if (Math.abs(pts) > 1000000) return res.status(400).json({ error: 'amount too large' });

    let targetId = user_id;
    if (!targetId && campus_id) {
      const { rows } = await db.query('SELECT id FROM users WHERE UPPER(campus_id) = $1', [String(campus_id).trim().toUpperCase()]);
      if (!rows.length) return res.status(404).json({ error: 'Student not found' });
      targetId = rows[0].id;
    }
    if (!targetId) return res.status(400).json({ error: 'user_id or campus_id required' });

    const { rows: u } = await db.query('SELECT id, name FROM users WHERE id = $1', [targetId]);
    if (!u.length) return res.status(404).json({ error: 'Student not found' });

    await db.query(
      `INSERT INTO points_ledger (id, user_id, amount, reason) VALUES ($1,$2,$3,$4)`,
      [uuidv4(), targetId, pts, `admin_grant:${(reason || 'reward').toString().slice(0, 60)}`]
    );
    const { rows: b } = await db.query('SELECT COALESCE(SUM(amount),0)::int AS bal FROM points_ledger WHERE user_id = $1', [targetId]);
    res.json({ user_id: targetId, name: u[0].name, granted: pts, new_balance: b[0].bal });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/stats ──────────────────────────────────────
exports.getStats = async (req, res) => {
  try {
    const [users, posts, reports, pendingJobs] = await Promise.all([
      db.query('SELECT COUNT(*) FROM users'),
      db.query('SELECT COUNT(*) FROM posts WHERE is_deleted = false'),
      db.query("SELECT COUNT(*) FROM reports WHERE status = 'pending'"),
      db.query("SELECT COUNT(*) FROM jobs WHERE is_approved = false"),
    ]);
    res.json({
      total_users: parseInt(users.rows[0].count),
      total_posts: parseInt(posts.rows[0].count),
      pending_reports: parseInt(reports.rows[0].count),
      pending_jobs: parseInt(pendingJobs.rows[0].count),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/reports ────────────────────────────────────
exports.getReports = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT r.*, row_to_json(u.*) AS reporter
       FROM reports r JOIN users u ON u.id = r.reporter_id
       WHERE r.status = 'pending'
       ORDER BY r.created_at DESC LIMIT 50`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /admin/reports/:id/resolve ───────────────────────
exports.resolveReport = async (req, res) => {
  try {
    const { action } = req.body; // 'dismiss' | 'delete_content' | 'ban_user'
    const { rows: report } = await db.query(
      `UPDATE reports SET status = 'resolved', resolution = $1, resolved_at = NOW()
       WHERE id = $2 RETURNING *`,
      [action, req.params.id]
    );
    if (!report.length) return res.status(404).json({ error: 'Report not found' });

    if (action === 'delete_content' && report[0].target_type === 'post') {
      await db.query('UPDATE posts SET is_deleted = true WHERE id = $1', [report[0].target_id]);
    }
    if (action === 'ban_user') {
      await db.query('UPDATE users SET is_banned = true WHERE id = $1', [report[0].reported_user_id]);
      await admin.auth().updateUser(report[0].firebase_uid, { disabled: true });
    }

    res.json(report[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/jobs/pending ───────────────────────────────
exports.getPendingJobs = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT j.*, row_to_json(u.*) AS posted_by
       FROM jobs j JOIN users u ON u.id = j.poster_id
       WHERE j.is_approved = false ORDER BY j.created_at DESC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /admin/jobs/:id/approve ───────────────────────────
exports.approveJob = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE jobs SET is_approved = true WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Job not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /admin/notes/:id/approve ──────────────────────────
exports.approveNote = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE notes SET is_approved = true WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Note not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/users?page=1&limit=20&q=&is_banned=&state=&city=&college= ──
exports.getUsers = async (req, res) => {
  try {
    const { page = 1, limit = 20, q, is_banned, state, city, college } = req.query;
    const offset = (page - 1) * limit;
    const conditions = [];
    const params = [];
    let pi = 1;

    if (q) {
      conditions.push(
        `(u.name ILIKE $${pi} OR u.email ILIKE $${pi} OR u.campus_id ILIKE $${pi})`
      );
      params.push(`%${q}%`);
      pi++;
    }
    if (is_banned === 'true') conditions.push('u.is_banned = true');
    if (is_banned === 'false') conditions.push('u.is_banned = false');
    if (state && state.trim().length > 0) {
      conditions.push(`u.state ILIKE $${pi}`);
      params.push(`%${state.trim()}%`);
      pi++;
    }
    if (city && city.trim().length > 0) {
      conditions.push(`u.city ILIKE $${pi}`);
      params.push(`%${city.trim()}%`);
      pi++;
    }
    if (college && college.trim().length > 0) {
      conditions.push(`(u.college ILIKE $${pi} OR u.college_name ILIKE $${pi})`);
      params.push(`%${college.trim()}%`);
      pi++;
    }

    const whereClause = conditions.length
      ? 'WHERE ' + conditions.join(' AND ')
      : '';

    params.push(parseInt(limit), parseInt(offset));

    const { rows } = await db.query(
      `SELECT u.id, u.name, u.email, u.campus_id, u.college, u.state, u.city,
         u.course, u.branch, u.year_of_study, u.photo_url, u.is_banned,
         u.is_admin, u.is_verified, u.is_premium, u.role, u.college_name, u.created_at,
         (SELECT COALESCE(SUM(amount), 0)::int FROM points_ledger WHERE user_id = u.id) AS points,
         (SELECT COUNT(*)::int FROM posts WHERE author_id = u.id AND is_deleted = false) AS post_count,
         (SELECT COUNT(*)::int FROM connections
          WHERE (requester_id = u.id OR receiver_id = u.id) AND status = 'accepted') AS connections_count
       FROM users u
       ${whereClause}
       ORDER BY u.created_at DESC
       LIMIT $${pi++} OFFSET $${pi}`,
      params
    );

    const { rows: countRows } = await db.query(
      `SELECT COUNT(*)::int AS total FROM users u ${whereClause}`,
      params.slice(0, -2)
    );

    res.json({
      data: rows,
      total: countRows[0]?.total || rows.length,
      page: parseInt(page),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/users/meta ─────────────────────────────────
exports.getUsersMeta = async (req, res) => {
  try {
    const [statesRes, citiesRes, collegesRes] = await Promise.all([
      db.query(`SELECT DISTINCT state FROM users WHERE state IS NOT NULL AND state != '' ORDER BY state ASC`),
      db.query(`SELECT DISTINCT city FROM users WHERE city IS NOT NULL AND city != '' ORDER BY city ASC`),
      db.query(`SELECT DISTINCT COALESCE(college, college_name) AS college FROM users WHERE (college IS NOT NULL AND college != '') OR (college_name IS NOT NULL AND college_name != '') ORDER BY college ASC`),
    ]);
    res.json({
      states: statesRes.rows.map(r => r.state),
      cities: citiesRes.rows.map(r => r.city),
      colleges: collegesRes.rows.map(r => r.college),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /admin/users/:id/block ────────────────────────────
exports.blockUser = async (req, res) => {
  try {
    const { reason } = req.body;
    const { rows } = await db.query(
      'UPDATE users SET is_banned = true WHERE id = $1 RETURNING id, name, email, is_banned',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });

    // Disable in Firebase Auth
    try {
      const { rows: u } = await db.query(
        'SELECT firebase_uid FROM users WHERE id = $1',
        [req.params.id]
      );
      if (u.length && u[0].firebase_uid) {
        await admin.auth().updateUser(u[0].firebase_uid, { disabled: true });
      }
    } catch (_) {}

    res.json({ ...rows[0], blocked: true, reason });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /admin/users/:id/unblock ──────────────────────────
exports.unblockUser = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE users SET is_banned = false WHERE id = $1 RETURNING id, name, email, is_banned',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });

    // Re-enable in Firebase Auth
    try {
      const { rows: u } = await db.query(
        'SELECT firebase_uid FROM users WHERE id = $1',
        [req.params.id]
      );
      if (u.length && u[0].firebase_uid) {
        await admin.auth().updateUser(u[0].firebase_uid, { disabled: false });
      }
    } catch (_) {}

    res.json({ ...rows[0], blocked: false });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /admin/users/:id/freeze ──────────────────────────
exports.freezeUser = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE users SET is_banned = true WHERE id = $1 RETURNING id, name, firebase_uid',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    try {
      if (rows[0].firebase_uid) {
        await admin.auth().updateUser(rows[0].firebase_uid, { disabled: true });
      }
    } catch (_) {}
    activityLog.dismissActivity(req.params.id);
    res.json({ frozen: true, user_id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /admin/users/:id/restrict ───────────────────────
exports.restrictUser = async (req, res) => {
  try {
    await db.query('UPDATE users SET is_premium = false WHERE id = $1', [
      req.params.id,
    ]);
    activityLog.dismissActivity(req.params.id);
    res.json({ restricted: true, user_id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/pulse/stats ────────────────────────────────
exports.getPulseStats = (req, res) => {
  try {
    res.json(activityLog.getPulseStats());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/pulse/live-feed?limit=20 ───────────────────
exports.getLiveFeed = (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    res.json({ data: activityLog.getLiveFeed(limit) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /admin/pulse/suspicious ───────────────────────────
exports.getSuspiciousActivities = (req, res) => {
  try {
    res.json({ data: activityLog.getSuspiciousActivities() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /admin/pulse/suspicious/:userId/dismiss ──────────
exports.dismissSuspicious = (req, res) => {
  try {
    activityLog.dismissActivity(req.params.userId);
    res.json({ dismissed: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /admin/broadcast ─────────────────────────────────
exports.broadcast = async (req, res) => {
  try {
    const { title, body, topic = 'all_students' } = req.body;
    const message = {
      notification: { title, body },
      topic,
    };
    const result = await admin.messaging().send(message);
    res.json({ success: true, messageId: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
exports.redeemDeal = async (req, res) => {
  try {
    const { deal_id, deal_code } = req.body;
    if (!deal_id || !deal_code) return res.status(400).json({ error: 'Deal ID and Deal Code are required' });

    // Find the user by deal_code
    const { rows: users } = await db.query('SELECT id, name FROM users WHERE deal_code = ', [deal_code.toUpperCase()]);
    if (!users.length) return res.status(404).json({ error: 'Invalid Deal Code' });
    const user = users[0];

    // Check if already redeemed
    const { rows: redemptions } = await db.query('SELECT id FROM deal_redemptions WHERE deal_id =  AND user_id = ', [deal_id, user.id]);
    if (redemptions.length) return res.status(400).json({ error: 'Deal already redeemed by this user' });

    // Redeem
    await db.query('INSERT INTO deal_redemptions (deal_id, user_id) VALUES (, )', [deal_id, user.id]);
    
    res.json({ success: true, message: 'Deal successfully redeemed!', user: { name: user.name } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
