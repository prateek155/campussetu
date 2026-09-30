// src/controllers/flatmates.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const cache = require('../config/redis');
const FLATMATES_CACHE_KEY = 'flatmates:active';
const FLATMATES_CACHE_TTL = 120;

function fullUrl(req, p) {
  if (!p) return null;
  if (p.startsWith('http')) return p;
  return `${req.protocol}://${req.get('host')}${p}`;
}

async function queryActiveFlatmates() {
  const { rows } = await db.query(
    `SELECT f.*, u.name AS poster_name, u.college, u.photo_url AS avatar
     FROM flatmates f
     LEFT JOIN users u ON u.id = f.poster_id
     WHERE f.status = 'active'
     ORDER BY f.created_at DESC
     LIMIT 50`
  );
  return rows;
}

function withPublicPhotoUrls(req, rows) {
  return rows.map((row) => ({
    ...row,
    photo_url_1: fullUrl(req, row.photo_url_1),
    photo_url_2: fullUrl(req, row.photo_url_2),
    avatar: fullUrl(req, row.avatar),
  }));
}

async function refreshActiveFlatmates() {
  await cache.invalidateJson(FLATMATES_CACHE_KEY);
  const result = { data: await queryActiveFlatmates() };
  await cache.setJson(FLATMATES_CACHE_KEY, result, FLATMATES_CACHE_TTL);
  return result;
}

async function invalidateAndWarmFlatmates() {
  try {
    await refreshActiveFlatmates();
  } catch (error) {
    // Keep successful listing changes successful if the optional cache cannot warm.
    console.warn('[Flatmates] cache refresh deferred:', error.message);
  }
}

// GET /flatmates  — public, active listings only
exports.getFlatmates = async (req, res) => {
  try {
    res.setHeader('Cache-Control', 'private, no-store');
    const result = await cache.getOrLoadJson(
      FLATMATES_CACHE_KEY,
      FLATMATES_CACHE_TTL,
      async () => ({ data: await queryActiveFlatmates() }),
    );
    res.json({ data: withPublicPhotoUrls(req, result.data || []) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// POST /flatmates  — auth required, multipart with up to 2 photos
exports.createFlatmate = async (req, res) => {
  try {
    const { name, place, num_persons, contact_number, description } = req.body;
    if (!name || !place || !contact_number) {
      return res
        .status(400)
        .json({ error: 'name, place, contact_number are required' });
    }

    const { rows: u } = await db.query(
      'SELECT id FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!u.length) return res.status(404).json({ error: 'User not found' });
    const posterId = u[0].id;

    const files = req.files || [];
    const photo1 = files[0] ? `/uploads/${files[0].filename}` : null;
    const photo2 = files[1] ? `/uploads/${files[1].filename}` : null;

    const { rows } = await db.query(
      `INSERT INTO flatmates
         (id, poster_id, name, place, num_persons, contact_number, description, photo_url_1, photo_url_2, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active')
       RETURNING *`,
      [
        uuidv4(),
        posterId,
        name.trim(),
        place.trim(),
        parseInt(num_persons) || 1,
        contact_number.trim(),
        description?.trim() || null,
        photo1,
        photo2,
      ]
    );

    rows[0].photo_url_1 = fullUrl(req, rows[0].photo_url_1);
    rows[0].photo_url_2 = fullUrl(req, rows[0].photo_url_2);
    await invalidateAndWarmFlatmates();
    await cache.delCache('home:counts');
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// DELETE /flatmates/:id  — own listing or admin
exports.deleteFlatmate = async (req, res) => {
  try {
    const { rows: u } = await db.query(
      'SELECT id, is_admin FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!u.length) return res.status(404).json({ error: 'User not found' });

    const isAdmin = !!u[0].is_admin;
    const query = isAdmin
      ? 'DELETE FROM flatmates WHERE id = $1 RETURNING id'
      : 'DELETE FROM flatmates WHERE id = $1 AND poster_id = $2 RETURNING id';
    const params = isAdmin ? [req.params.id] : [req.params.id, u[0].id];

    const { rows } = await db.query(query, params);
    if (!rows.length) {
      return res
        .status(404)
        .json({ error: 'Listing not found or not authorized' });
    }
    await invalidateAndWarmFlatmates();
    await cache.delCache('home:counts');
    res.json({ deleted: req.params.id });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// GET /admin/flatmates  — admin sees all statuses
exports.adminGetFlatmates = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT f.*, u.name AS poster_name, u.email AS poster_email
       FROM flatmates f
       LEFT JOIN users u ON u.id = f.poster_id
       ORDER BY f.created_at DESC
       LIMIT 100`
    );
    res.json({ data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
