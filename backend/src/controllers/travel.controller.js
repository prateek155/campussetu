// backend/src/controllers/travel.controller.js
const db = require('../config/db');
const cache = require('../config/redis');

// ── GET /api/v1/travel ─────────────────────────────────────────
exports.getRides = async (req, res) => {
  try {
    const cached = await cache.getCache('travel:active');
    if (cached) return res.json(JSON.parse(cached));

    const { rows } = await db.query(
      `SELECT t.*, u.name as user_name, u.college, u.avatar 
       FROM travel_rides t
       JOIN users u ON t.user_id = u.id
       WHERE t.status = 'active'
       ORDER BY t.created_at DESC`
    );
    await cache.setCache('travel:active', JSON.stringify(rows), 30); // 30 sec
    res.json(rows);
  } catch (err) {
    console.error('Error fetching travel rides:', err);
    res.status(500).json({ error: err.message });
  }
};

// ── POST /api/v1/travel ────────────────────────────────────────
exports.createRide = async (req, res) => {
  try {
    const { vehicle_type, destination, time_date, contact_number } = req.body;
    
    // Find the current user ID
    const { rows: userRows } = await db.query(
      'SELECT id FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );

    if (userRows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userId = userRows[0].id;

    const { rows } = await db.query(
      `INSERT INTO travel_rides 
       (user_id, vehicle_type, destination, time_date, contact_number, status) 
       VALUES ($1, $2, $3, $4, $5, 'active') 
       RETURNING *`,
      [userId, vehicle_type, destination, time_date, contact_number]
    );

    // Invalidate travel cache so next GET reflects new ride
    await cache.delCache('travel:active');

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating travel ride:', err);
    res.status(500).json({ error: err.message });
  }
};
