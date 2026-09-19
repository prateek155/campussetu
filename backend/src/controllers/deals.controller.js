// backend/src/controllers/deals.controller.js
const db = require('../config/db');
const cache = require('../config/redis');

exports.createDeal = async (req, res) => {
  try {
    let { title, description, discount_code, banner_url } = req.body;
    
    if (req.file) {
      banner_url = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    if (!title || !description) {
      return res.status(400).json({ error: 'Title and description are required' });
    }

    const { rows } = await db.query(
      `INSERT INTO deals (title, description, discount_code, banner_url) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [title, description, discount_code, banner_url]
    );

    // Invalidate deals cache
    await cache.delCache('deals:all');

    return res.status(201).json({ deal: rows[0] });
  } catch (error) {
    console.error('Error creating deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteDeal = async (req, res) => {
  try {
    const { rows } = await db.query(
      'DELETE FROM deals WHERE id = $1 RETURNING id',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Deal not found' });
    await cache.delCache('deals:all');
    return res.json({ deleted: req.params.id });
  } catch (error) {
    console.error('Error deleting deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getDeals = async (req, res) => {
  try {
    const cached = await cache.getCache('deals:all');
    if (cached) return res.json(JSON.parse(cached));

    const { rows } = await db.query(
      `SELECT * FROM deals ORDER BY created_at DESC LIMIT 50`
    );
    const result = { deals: rows };
    await cache.setCache('deals:all', JSON.stringify(result), 300); // 5 min
    return res.json(result);
  } catch (error) {
    console.error('Error fetching deals:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
