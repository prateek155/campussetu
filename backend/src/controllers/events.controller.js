// backend/src/controllers/events.controller.js
const db = require('../config/db');
const cache = require('../config/redis');

exports.createEvent = async (req, res) => {
  try {
    const { name, description, place, time_date, registration_link, picture_url } = req.body;
    
    if (!name || !description || !place || !time_date || !registration_link) {
      return res.status(400).json({ error: 'All fields except picture are required' });
    }

    const { rows } = await db.query(
      `INSERT INTO events (name, description, place, time_date, registration_link, picture_url) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [name, description, place, time_date, registration_link, picture_url]
    );

    // Invalidate events cache
    await cache.delCache('events:all');

    return res.status(201).json({ event: rows[0] });
  } catch (error) {
    console.error('Error creating event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteEvent = async (req, res) => {
  try {
    const { rows } = await db.query(
      'DELETE FROM events WHERE id = $1 RETURNING id',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Event not found' });
    await cache.delCache('events:all');
    return res.json({ deleted: req.params.id });
  } catch (error) {
    console.error('Error deleting event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getEvents = async (req, res) => {
  try {
    const cached = await cache.getCache('events:all');
    if (cached) return res.json(JSON.parse(cached));

    const { rows } = await db.query(
      `SELECT * FROM events ORDER BY created_at DESC LIMIT 50`
    );
    const result = { events: rows };
    await cache.setCache('events:all', JSON.stringify(result), 300); // 5 min
    return res.json(result);
  } catch (error) {
    console.error('Error fetching events:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
