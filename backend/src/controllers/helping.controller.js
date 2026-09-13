// backend/src/controllers/helping.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

async function meId(firebaseUid) {
  const { rows } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [firebaseUid]);
  return rows.length ? rows[0].id : null;
}

function fullImageUrl(req, p) {
  if (!p) return null;
  if (p.startsWith('http')) return p;
  return `${req.protocol}://${req.get('host')}${p}`;
}

async function sweepExpired() {
  try {
    await db.query(
      `UPDATE helping_tasks SET status = 'on_hold'
       WHERE status = 'open' AND COALESCE(expires_at, created_at + INTERVAL '7 days') <= NOW()`
    );
  } catch (_) {}
}

// ── GET /helping?type=paid|points|mine ──
exports.getTasks = async (req, res) => {
  try {
    await sweepExpired();
    const { type, mine, status = 'open', page = 1, limit = 20, q } = req.query;
    const offset = (page - 1) * limit;
    const conditions = [];
    const params = [];
    let pi = 1;

    if (type === 'paid' || type === 'points') { conditions.push(`t.type = $${pi++}`); params.push(type); }
    if (status && status !== 'all') { conditions.push(`t.status = $${pi++}`); params.push(status); }
    if (q) { conditions.push(`(t.title ILIKE $${pi} OR t.description ILIKE $${pi})`); params.push(`%${q}%`); pi++; }
    if (mine === 'true') {
      const uid = await meId(req.user.uid);
      conditions.push(`t.poster_id = $${pi++}`); params.push(uid);
    } else {
      const uid = await meId(req.user.uid);
      if (uid) { conditions.push(`t.poster_id != $${pi++}`); params.push(uid); }
      conditions.push(`t.status != 'on_hold'`);
      conditions.push(`COALESCE(t.expires_at, t.created_at + INTERVAL '7 days') > NOW()`);
    }

    params.push(parseInt(limit), parseInt(offset));
    const { rows } = await db.query(
      `SELECT t.*,
        (SELECT COUNT(*)::int FROM helping_applications a WHERE a.task_id = t.id) AS applications_count,
        row_to_json(u.*) AS poster
       FROM helping_tasks t JOIN users u ON u.id = t.poster_id
       ${conditions.length ? 'WHERE ' + conditions.join(' AND ') : ''}
       ORDER BY t.created_at DESC LIMIT $${pi++} OFFSET $${pi}`,
      params
    );
    rows.forEach((r) => { r.image_url = fullImageUrl(req, r.image_url); });
    res.json({ data: rows, page: parseInt(page) });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── POST /helping (multipart: image max 2MB) ──
exports.createTask = async (req, res) => {
  try {
    const { title, description, type, amount, points, deadline } = req.body;
    if (!title || !description) return res.status(400).json({ error: 'title & description required' });
    if (type !== 'paid' && type !== 'points') return res.status(400).json({ error: 'type must be paid|points' });
    let amt = null, pts = null;
    if (type === 'paid') {
      amt = parseFloat(amount);
      if (!amt || amt <= 0) return res.status(400).json({ error: 'valid amount required for paid task' });
      if (!deadline) return res.status(400).json({ error: 'deadline required for paid task' });
    } else {
      pts = parseInt(points);
      if (!pts || pts <= 0) return res.status(400).json({ error: 'valid points required' });
    }
    const uid = await meId(req.user.uid);
    if (!uid) return res.status(404).json({ error: 'User not found' });
    if (type === 'points') {
      const { rows: b } = await db.query('SELECT COALESCE(SUM(amount),0)::int AS bal FROM points_ledger WHERE user_id = $1', [uid]);
      if ((b[0].bal || 0) < pts) return res.status(400).json({ error: `Insufficient points. Balance: ${b[0].bal}` });
    }
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const { rows } = await db.query(
      `INSERT INTO helping_tasks (id, title, description, image_url, type, amount, points, deadline, poster_id, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'open', NOW() + INTERVAL '7 days') RETURNING *`,
      [uuidv4(), title.trim(), description.trim(), imageUrl, type, amt, pts, deadline || null, uid]
    );
    rows[0].image_url = fullImageUrl(req, rows[0].image_url);
    res.status(201).json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── DELETE /helping/:id (poster only) ──
exports.deleteTask = async (req, res) => {
  try {
    const uid = await meId(req.user.uid);
    if (!uid) return res.status(404).json({ error: 'User not found' });
    const { rows } = await db.query('DELETE FROM helping_tasks WHERE id = $1 AND poster_id = $2 RETURNING id', [req.params.id, uid]);
    if (!rows.length) return res.status(404).json({ error: 'Task not found or not authorized' });
    res.json({ deleted: req.params.id });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── GET /helping/:id ──
exports.getTask = async (req, res) => {
  try {
    await sweepExpired();
    const { rows } = await db.query(
      `SELECT t.*, row_to_json(u.*) AS poster,
        (SELECT COUNT(*)::int FROM helping_applications a WHERE a.task_id = t.id) AS applications_count
       FROM helping_tasks t JOIN users u ON u.id = t.poster_id WHERE t.id = $1`, [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Task not found' });
    rows[0].image_url = fullImageUrl(req, rows[0].image_url);
    const { rows: apps } = await db.query(
      `SELECT a.*, row_to_json(u.*) AS applicant FROM helping_applications a
       JOIN users u ON u.id = a.applicant_id WHERE a.task_id = $1 ORDER BY a.created_at ASC`, [req.params.id]
    );
    const uid = await meId(req.user.uid);
    const mine = apps.find((a) => a.applicant_id === uid);
    res.json({ ...rows[0], applications: apps, my_application: mine || null, is_poster: rows[0].poster_id === uid });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── POST /helping/:id/apply ──
exports.applyTask = async (req, res) => {
  try {
    const uid = await meId(req.user.uid);
    const { rows: t } = await db.query('SELECT * FROM helping_tasks WHERE id = $1', [req.params.id]);
    if (!t.length) return res.status(404).json({ error: 'Task not found' });
    if (t[0].poster_id === uid) return res.status(400).json({ error: 'Cannot apply to own task' });
    if (t[0].status === 'on_hold' || (t[0].expires_at && new Date(t[0].expires_at) <= new Date())) return res.status(410).json({ error: 'Task on hold (expired after 7 days)' });
    if (t[0].status !== 'open') return res.status(400).json({ error: 'Task not open' });
    const { rows } = await db.query(
      `INSERT INTO helping_applications (id, task_id, applicant_id, status) VALUES ($1,$2,$3,'applied')
       ON CONFLICT (task_id, applicant_id) DO NOTHING RETURNING *`,
      [uuidv4(), req.params.id, uid]
    );
    if (!rows.length) return res.status(400).json({ error: 'Already applied' });
    res.status(201).json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── POST /helping/:id/accept {applicant_id} ──
exports.acceptApplication = async (req, res) => {
  try {
    const uid = await meId(req.user.uid);
    const { applicant_id } = req.body;
    if (!applicant_id) return res.status(400).json({ error: 'applicant_id required' });
    const { rows: t } = await db.query('SELECT * FROM helping_tasks WHERE id = $1', [req.params.id]);
    if (!t.length) return res.status(404).json({ error: 'Task not found' });
    if (t[0].poster_id !== uid) return res.status(403).json({ error: 'Only poster can accept' });
    if (t[0].status === 'on_hold' || (t[0].expires_at && new Date(t[0].expires_at) <= new Date())) return res.status(410).json({ error: 'Task on hold (expired after 7 days)' });
    if (t[0].status !== 'open') return res.status(400).json({ error: 'Task not open' });
    await db.query(`UPDATE helping_applications SET status='rejected' WHERE task_id=$1 AND applicant_id!=$2`, [req.params.id, applicant_id]);
    const { rows: acc } = await db.query(
      `UPDATE helping_applications SET status='accepted' WHERE task_id=$1 AND applicant_id=$2 RETURNING *`, [req.params.id, applicant_id]
    );
    if (!acc.length) return res.status(404).json({ error: 'Application not found' });
    await db.query(`UPDATE helping_tasks SET status='assigned', assignee_id=$2 WHERE id=$1`, [req.params.id, applicant_id]);
    res.json({ task_id: req.params.id, accepted: acc[0] });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── POST /helping/:id/complete → points transfer (atomic) ──
exports.completeTask = async (req, res) => {
  try {
    const uid = await meId(req.user.uid);
    const { rows: t } = await db.query('SELECT * FROM helping_tasks WHERE id = $1', [req.params.id]);
    if (!t.length) return res.status(404).json({ error: 'Task not found' });
    if (t[0].poster_id !== uid) return res.status(403).json({ error: 'Only poster can complete' });
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const { rows: locked } = await client.query('SELECT * FROM helping_tasks WHERE id = $1 FOR UPDATE', [req.params.id]);
      const task = locked[0];
      if (!task || task.status === 'completed') { await client.query('ROLLBACK'); return res.status(400).json({ error: 'Already completed' }); }
      if (task.status !== 'assigned' || !task.assignee_id) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'No assignee yet' }); }
      if (task.type === 'points') {
        await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [uid]);
        const { rows: b } = await client.query('SELECT COALESCE(SUM(amount),0)::int AS bal FROM points_ledger WHERE user_id=$1', [uid]);
        if (b[0].bal < task.points) { await client.query('ROLLBACK'); return res.status(400).json({ error: `Insufficient points. Balance: ${b[0].bal}` }); }
        await client.query(`INSERT INTO points_ledger (id, user_id, amount, reason) VALUES ($1,$2,$3,$4)`, [uuidv4(), uid, -task.points, `helping_reward_sent:${task.id}`]);
        await client.query(`INSERT INTO points_ledger (id, user_id, amount, reason) VALUES ($1,$2,$3,$4)`, [uuidv4(), task.assignee_id, task.points, `helping_reward_received:${task.id}`]);
      }
      await client.query(`UPDATE helping_tasks SET status='completed' WHERE id=$1`, [task.id]);
      await client.query('COMMIT');
      res.json({ task_id: task.id, status: 'completed', transferred_points: task.type === 'points' ? task.points : 0 });
    } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
  } catch (err) { res.status(500).json({ error: err.message }); }
};
