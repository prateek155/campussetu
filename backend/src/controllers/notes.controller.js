// backend/src/controllers/notes.controller.js
const db = require('../config/db');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// ── GET /notes ────────────────────────────────────────────
exports.getNotes = async (req, res) => {
  try {
    const { subject, q, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const conditions = ['n.is_approved = true'];
    const params = [];
    let pi = 1;

    if (subject) { conditions.push(`n.subject = $${pi++}`); params.push(subject); }
    if (q) {
      conditions.push(`(n.title ILIKE $${pi} OR n.subject ILIKE $${pi})`);
      params.push(`%${q}%`); pi++;
    }

    params.push(parseInt(limit), parseInt(offset));

    const { rows } = await db.query(
      `SELECT n.*, row_to_json(u.*) AS uploader
       FROM notes n JOIN users u ON u.id = n.uploader_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY n.download_count DESC, n.created_at DESC
       LIMIT $${pi++} OFFSET $${pi}`,
      params
    );
    res.json({ data: rows, page: parseInt(page) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /notes ───────────────────────────────────────────
// Uses multer (configured in the route)
exports.uploadNote = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const { title, subject } = req.body;
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const fileUrl = `/uploads/${req.file.filename}`;
    const fileSizeMb = (req.file.size / (1024 * 1024)).toFixed(2);

    const { rows } = await db.query(
      `INSERT INTO notes (id, title, subject, file_url, file_size_mb, uploader_id, is_approved)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [uuidv4(), title, subject, fileUrl, fileSizeMb, me[0].id, false]
    );
    res.status(201).json({ ...rows[0], message: 'Note uploaded, pending admin approval' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /notes/:id/download ──────────────────────────────
exports.incrementDownload = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE notes SET download_count = download_count + 1 WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Note not found' });
    res.json({ file_url: rows[0].file_url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
