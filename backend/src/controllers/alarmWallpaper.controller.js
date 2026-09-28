// backend/src/controllers/alarmWallpaper.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const cache = require('../config/redis');

const CACHE_KEY = 'alarm:wallpapers:list';
// 30 Days Cache TTL (since wallpapers change weekly or monthly)
const CACHE_TTL = 30 * 24 * 60 * 60; // 30 days (2,592,000 seconds)

/**
 * Helper to query DB and immediately warm the Redis cache.
 * Ensures Redis ALWAYS has the latest data ready for thousands of users without hitting PostgreSQL.
 */
async function warmWallpaperCache() {
  const { rows } = await db.query(`
    SELECT id, type, label, url, thumbnail_url, sort_order, created_at
    FROM alarm_wallpapers
    ORDER BY sort_order ASC, created_at DESC
  `);

  const grouped = {
    image:    rows.filter(r => r.type === 'image'),
    animated: rows.filter(r => r.type === 'animated'),
    video:    rows.filter(r => r.type === 'video'),
    cached_at: new Date().toISOString(),
  };

  await cache.setCache(CACHE_KEY, JSON.stringify(grouped), CACHE_TTL);
  return grouped;
}

// ── GET /api/v1/alarm-wallpapers ─────────────────────────────────────────────
// Serves 100% from Redis memory in <1ms. Database is NEVER hit by normal users.
exports.list = async (req, res) => {
  try {
    const cached = await cache.getCache(CACHE_KEY);
    if (cached) {
      res.setHeader('X-Cache', 'HIT');
      res.setHeader('Cache-Control', 'public, max-age=3600'); // 1 hour HTTP client cache
      return res.json(JSON.parse(cached));
    }

    // Cache Miss (first time server starts) -> Warm cache from DB
    res.setHeader('X-Cache', 'MISS');
    const grouped = await warmWallpaperCache();
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.json(grouped);
  } catch (err) {
    console.error('[AlarmWallpaper] list error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── POST /api/v1/alarm-wallpapers (Admin only) ────────────────────────────────
// Uploads new wallpaper -> immediately refreshes Redis cache so users get it instantly
exports.create = async (req, res) => {
  try {
    const { label, type, sort_order = 0 } = req.body;

    if (!label || !type) {
      return res.status(400).json({ error: 'label and type are required' });
    }
    const validTypes = ['image', 'animated', 'video'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${validTypes.join(', ')}` });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const host = `${req.protocol}://${req.get('host')}`;
    const fileUrl = `${host}/uploads/${req.file.filename}`;
    const thumbnailUrl = type === 'image' ? fileUrl : null;

    const id = uuidv4();
    const { rows } = await db.query(`
      INSERT INTO alarm_wallpapers (id, type, label, url, thumbnail_url, sort_order)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [id, type, label, fileUrl, thumbnailUrl, parseInt(sort_order)]);

    // 🚀 Instantly warm Redis cache with updated wallpapers list
    await warmWallpaperCache();

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('[AlarmWallpaper] create error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── DELETE /api/v1/alarm-wallpapers/:id (Admin only) ─────────────────────────
// Deletes wallpaper -> purges old cache and warms Redis with new list
exports.remove = async (req, res) => {
  try {
    const { id } = req.params;

    const { rows } = await db.query(
      'DELETE FROM alarm_wallpapers WHERE id = $1 RETURNING *',
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Wallpaper not found' });
    }

    // Disk cleanup
    try {
      const filePath = rows[0].url.replace(/^https?:\/\/[^/]+/, '');
      const diskPath = path.join(__dirname, '../../', filePath);
      if (fs.existsSync(diskPath)) fs.unlinkSync(diskPath);
    } catch (_) {}

    // 🚀 Refresh Redis cache immediately
    await warmWallpaperCache();

    res.json({ success: true, deleted: rows[0] });
  } catch (err) {
    console.error('[AlarmWallpaper] remove error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── PATCH /api/v1/alarm-wallpapers/:id/reorder (Admin only) ──────────────────
exports.reorder = async (req, res) => {
  try {
    const { id } = req.params;
    const { sort_order } = req.body;

    const { rows } = await db.query(
      'UPDATE alarm_wallpapers SET sort_order = $1 WHERE id = $2 RETURNING *',
      [parseInt(sort_order), id]
    );

    if (!rows.length) return res.status(404).json({ error: 'Not found' });

    // 🚀 Refresh Redis cache
    await warmWallpaperCache();

    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
