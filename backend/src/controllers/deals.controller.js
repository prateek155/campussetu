// backend/src/controllers/deals.controller.js
const db = require('../config/db');
const cache = require('../config/redis');
const DEALS_CACHE_TTL = 300;

function getDealsCacheKey(city, state) {
  const c = (city || 'all').toString().trim().toLowerCase();
  const s = (state || 'all').toString().trim().toLowerCase();
  return `deals:${c}:${s}:v3`;
}

async function queryDeals(city, state) {
  let query = `
    SELECT id, title, description, discount_code, banner_url, city, state, created_at
    FROM deals
  `;
  const conditions = [];
  const params = [];

  const cleanCity = city && typeof city === 'string' ? city.trim().toLowerCase() : null;
  const cleanState = state && typeof state === 'string' ? state.trim().toLowerCase() : null;

  if (cleanCity && cleanCity !== 'all') {
    params.push(cleanCity);
    conditions.push(`(LOWER(city) = $${params.length} OR city IS NULL OR LOWER(city) = 'all' OR LOWER(city) = '')`);
  }
  if (cleanState && cleanState !== 'all') {
    params.push(cleanState);
    conditions.push(`(LOWER(state) = $${params.length} OR state IS NULL OR LOWER(state) = 'all' OR LOWER(state) = '')`);
  }

  if (conditions.length > 0) {
    query += ` WHERE ${conditions.join(' AND ')}`;
  }

  if (cleanCity && cleanCity !== 'all') {
    query += ` ORDER BY CASE WHEN LOWER(city) = $1 THEN 0 ELSE 1 END, created_at DESC LIMIT 50`;
  } else {
    query += ` ORDER BY created_at DESC LIMIT 50`;
  }

  const { rows } = await db.query(query, params);
  return { deals: rows };
}

async function invalidateAndWarmDeals() {
  await cache.delCache('deals:all', 'deals:list');
  await cache.delCache('home:counts');
  await cache.invalidateJson(getDealsCacheKey());
}

exports.createDeal = async (req, res) => {
  try {
    let { title, description, discount_code, banner_url, city, state } = req.body;
    
    if (req.file) {
      banner_url = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    if (!title || !description) {
      return res.status(400).json({ error: 'Title and description are required' });
    }

    const { rows } = await db.query(
      `INSERT INTO deals (title, description, discount_code, banner_url, city, state) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [
        title.trim(),
        description.trim(),
        discount_code ? discount_code.trim() : null,
        banner_url,
        city && city.trim() ? city.trim() : null,
        state && state.trim() ? state.trim() : null
      ]
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
    const { city, state } = req.query;
    const cacheKey = getDealsCacheKey(city, state);
    const result = await cache.getOrLoadJson(
      cacheKey,
      DEALS_CACHE_TTL,
      () => queryDeals(city, state)
    );
    return res.json(result);
  } catch (error) {
    console.error('Error fetching deals:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
