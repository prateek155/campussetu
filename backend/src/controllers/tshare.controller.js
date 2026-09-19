// backend/src/controllers/tshare.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const CODE_LENGTH = parseInt(process.env.TSHARE_CODE_LENGTH || '4');
const EXPIRY_HOURS = parseInt(process.env.TSHARE_EXPIRY_HOURS || '24');

function generateCode(len = CODE_LENGTH) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: len }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

// ── POST /tshare ──────────────────────────────────────────
exports.createTshare = async (req, res) => {
  try {
    const { content, language = 'text' } = req.body;

    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    // Generate unique 4-char code with collision check
    let code;
    let tries = 0;
    while (tries < 10) {
      code = generateCode();
      const { rows: exists } = await db.query(
        'SELECT id FROM tshares WHERE code = $1 AND expires_at > NOW()',
        [code]
      );
      if (!exists.length) break;
      tries++;
    }
    if (!code) return res.status(500).json({ error: 'Could not generate unique code' });

    const expiresAt = new Date(Date.now() + EXPIRY_HOURS * 3600 * 1000);

    const { rows } = await db.query(
      `INSERT INTO tshares (id, code, content, language, uploader_id, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [uuidv4(), code, content, language, me[0].id, expiresAt]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /tshare/:code ─────────────────────────────────────
exports.retrieveTshare = async (req, res) => {
  try {
    const { code } = req.params;
    const { rows } = await db.query(
      `SELECT t.*, row_to_json(u.*) AS uploader
       FROM tshares t JOIN users u ON u.id = t.uploader_id
       WHERE t.code = $1 AND t.expires_at > NOW()`,
      [code.toUpperCase()]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Code not found or expired' });
    }
    // Track retrieval
    await db.query('UPDATE tshares SET retrieve_count = retrieve_count + 1 WHERE id = $1', [rows[0].id]);
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /tshare/my ────────────────────────────────────────
exports.getMyShares = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      'SELECT * FROM tshares WHERE uploader_id = $1 ORDER BY created_at DESC LIMIT 20',
      [me[0].id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
