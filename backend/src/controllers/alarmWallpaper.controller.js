// backend/src/controllers/alarmWallpaper.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const cache = require('../config/redis');

const CACHE_KEY = 'alarm:wallpapers:list';
const CACHE_TTL = 5 * 60; // 5 minutes

// ── GET /api/v1/alarm-wallpapers ─────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const cached = await cache.getCache(CACHE_KEY);
    if (cached) return res.json(JSON.parse(cached));

    const { rows } = await db.query(`
      SELECT id, type, label, url, thumbnail_url, sort_order, created_at
      FROM alarm_wallpapers
      ORDER BY sort_order ASC, created_at DESC
    `);

    // Group by type for easy consumption in Flutter
    const grouped = {
      image:    rows.filter(r => r.type === 'image'),
      animated: rows.filter(r => r.type === 'animated'),
      video:    rows.filter(r => r.type === 'video'),
    };

    await cache.setCache(CACHE_KEY, JSON.stringify(grouped), CACHE_TTL);
    res.json(grouped);
  } catch (err) {
    console.error('[AlarmWallpaper] list error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── POST /api/v1/alarm-wallpapers (Admin only) ────────────────────────────────
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

    // Thumbnail — for videos/animated, use same file as placeholder
    // In production you'd generate a real thumbnail
    const thumbnailUrl = type === 'image' ? fileUrl : null;

    const id = uuidv4();
    const { rows } = await db.query(`
      INSERT INTO alarm_wallpapers (id, type, label, url, thumbnail_url, sort_order)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [id, type, label, fileUrl, thumbnailUrl, parseInt(sort_order)]);

    // Invalidate cache so users see the new wallpaper immediately
    await cache.delCache(CACHE_KEY);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('[AlarmWallpaper] create error:', err.message);
    res.status(500).json({ error: err.message });
  }
};

// ── DELETE /api/v1/alarm-wallpapers/:id (Admin only) ─────────────────────────
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

    // Try to delete file from disk
    try {
      const filePath = rows[0].url.replace(/^https?:\/\/[^/]+/, '');
      const diskPath = path.join(__dirname, '../../', filePath);
      if (fs.existsSync(diskPath)) fs.unlinkSync(diskPath);
    } catch (_) { /* ignore disk errors */ }

    await cache.delCache(CACHE_KEY);
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

    await cache.delCache(CACHE_KEY);
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
