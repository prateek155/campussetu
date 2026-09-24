// backend/src/controllers/connect.controller.js
const db = require('../config/db');

// ── POST /connect/request ─────────────────────────────────
exports.sendRequest = async (req, res) => {
  try {
    const { receiver_id } = req.body;
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });
    const requesterId = me[0].id;

    if (requesterId === receiver_id) return res.status(400).json({ error: 'Cannot connect with yourself' });

    // Check for existing connection
    const { rows: existing } = await db.query(
      `SELECT id, status FROM connections
       WHERE (requester_id = $1 AND receiver_id = $2) OR (requester_id = $2 AND receiver_id = $1)`,
      [requesterId, receiver_id]
    );
    if (existing.length) {
      return res.status(409).json({ error: 'Connection already exists', status: existing[0].status });
    }

    const { rows } = await db.query(
      'INSERT INTO connections (requester_id, receiver_id, status) VALUES ($1, $2, $3) RETURNING *',
      [requesterId, receiver_id, 'pending']
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PUT /connect/:id/respond ──────────────────────────────
exports.respondRequest = async (req, res) => {
  try {
    const { status } = req.body; // 'accepted' | 'rejected'
    if (!['accepted', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'status must be accepted or rejected' });
    }

    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `UPDATE connections SET status = $1, updated_at = NOW()
       WHERE id = $2 AND receiver_id = $3 RETURNING *`,
      [status, req.params.id, me[0].id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Request not found or not authorized' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /connect/my ───────────────────────────────────────
exports.getMyConnections = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `SELECT c.*,
         CASE WHEN c.requester_id = $1 THEN
           jsonb_build_object('id', r.id, 'name', r.name, 'photo_url', r.photo_url,
             'college', r.college, 'city', r.city, 'state', r.state, 'campus_id', r.campus_id, 'is_verified', r.is_verified)
         ELSE
           jsonb_build_object('id', q.id, 'name', q.name, 'photo_url', q.photo_url,
             'college', q.college, 'city', q.city, 'state', q.state, 'campus_id', q.campus_id, 'is_verified', q.is_verified)
         END AS other_user
       FROM connections c
       JOIN users q ON q.id = c.requester_id
       JOIN users r ON r.id = c.receiver_id
       WHERE (c.requester_id = $1 OR c.receiver_id = $1) AND c.status = 'accepted'
       ORDER BY c.updated_at DESC`,
      [me[0].id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /connect/pending ──────────────────────────────────
exports.getPendingRequests = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `SELECT c.*,
         jsonb_build_object('id', u.id, 'name', u.name, 'photo_url', u.photo_url,
           'college', u.college, 'city', u.city, 'campus_id', u.campus_id, 'is_verified', u.is_verified) AS requester
       FROM connections c
       JOIN users u ON u.id = c.requester_id
       WHERE c.receiver_id = $1 AND c.status = 'pending'
       ORDER BY c.created_at DESC`,
      [me[0].id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /connect/sent ─────────────────────────────────────
exports.getSentRequests = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `SELECT c.*,
         jsonb_build_object('id', u.id, 'name', u.name, 'photo_url', u.photo_url,
           'college', u.college, 'city', u.city, 'campus_id', u.campus_id, 'is_verified', u.is_verified) AS receiver
       FROM connections c
       JOIN users u ON u.id = c.receiver_id
       WHERE c.requester_id = $1 AND c.status = 'pending'
       ORDER BY c.created_at DESC`,
      [me[0].id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── DELETE /connect/:id ───────────────────────────────────
exports.removeConnection = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `DELETE FROM connections WHERE id = $1 AND (requester_id = $2 OR receiver_id = $2) RETURNING *`,
      [req.params.id, me[0].id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Connection not found' });
    res.json({ removed: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
