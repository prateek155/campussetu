// backend/src/controllers/jobs.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

// ── GET /jobs ─────────────────────────────────────────────
exports.getJobs = async (req, res) => {
  try {
    const { type, state, city, is_remote, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const conditions = ['j.is_approved = true'];
    const params = [];
    let pi = 1;

    if (type) { conditions.push(`j.type = $${pi++}`); params.push(type); }
    if (state) { conditions.push(`j.state = $${pi++}`); params.push(state); }
    if (city) { conditions.push(`j.city ILIKE $${pi++}`); params.push(`%${city}%`); }
    if (is_remote !== undefined) { conditions.push(`j.is_remote = $${pi++}`); params.push(is_remote === 'true'); }

    params.push(parseInt(limit), parseInt(offset));

    const { rows } = await db.query(
      `SELECT j.*, row_to_json(u.*) AS posted_by
       FROM jobs j JOIN users u ON u.id = j.poster_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY j.created_at DESC
       LIMIT $${pi++} OFFSET $${pi}`,
      params
    );
    res.json({ data: rows, page: parseInt(page) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /jobs ────────────────────────────────────────────
exports.createJob = async (req, res) => {
  try {
    const {
      title, company, description, type,
      state, city, is_remote = false, apply_url, deadline,
    } = req.body;

    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `INSERT INTO jobs (id, title, company, description, type, state, city, is_remote, apply_url, deadline, poster_id, is_approved)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [uuidv4(), title, company, description, type, state, city, is_remote, apply_url, deadline, me[0].id, false]
    );
    res.status(201).json({ ...rows[0], message: 'Job posted, pending admin approval' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /jobs/:id ─────────────────────────────────────────
exports.getJob = async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT j.*, row_to_json(u.*) AS posted_by FROM jobs j JOIN users u ON u.id = j.poster_id WHERE j.id = $1',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Job not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
