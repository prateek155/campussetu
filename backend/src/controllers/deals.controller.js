// backend/src/controllers/deals.controller.js
const db = require('../config/db');
const cache = require('../config/redis');
const DEALS_CACHE_KEY = 'deals:all:v2';
const DEALS_CACHE_TTL = 300;

async function queryDeals() {
  const { rows } = await db.query(
    `SELECT id, title, description, discount_code, banner_url, created_at
     FROM deals ORDER BY created_at DESC LIMIT 50`
  );
  return { deals: rows };
}

async function refreshDealsCache() {
  const result = await queryDeals();
  await cache.setJson(DEALS_CACHE_KEY, result, DEALS_CACHE_TTL);
  return result;
}

async function invalidateAndWarmDeals() {
  await cache.invalidateJson(DEALS_CACHE_KEY);
  await cache.delCache('deals:all', 'deals:list');
  await cache.delCache('home:counts');
  try {
    await refreshDealsCache();
  } catch (error) {
    // The database write already succeeded. Keep the endpoint successful;
    // the next read will retry the normal DB-backed cache fill.
    console.warn('[Deals] cache refresh deferred:', error.message);
  }
}

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

    await invalidateAndWarmDeals();

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
    await invalidateAndWarmDeals();
    return res.json({ deleted: req.params.id });
  } catch (error) {
    console.error('Error deleting deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getDeals = async (req, res) => {
  try {
    res.setHeader('Cache-Control', 'private, no-store');
    const result = await cache.getOrLoadJson(DEALS_CACHE_KEY, DEALS_CACHE_TTL, queryDeals);
    return res.json(result);
  } catch (error) {
    console.error('Error fetching deals:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
