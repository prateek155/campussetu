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
    SELECT d.id, d.title, d.description, d.discount_code, d.banner_url, d.city, d.state, d.created_at,
      COALESCE(r.redemptions_count, 0)::int AS redemptions_count
    FROM deals d
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::int AS redemptions_count
      FROM deal_redemptions dr
      WHERE dr.deal_id = d.id
    ) r ON TRUE
  `;
  const conditions = ['COALESCE(d.is_deleted, false) = false'];
  const params = [];

  const cleanCity = city && typeof city === 'string' ? city.trim().toLowerCase() : null;
  const cleanState = state && typeof state === 'string' ? state.trim().toLowerCase() : null;

  if (cleanCity && cleanCity !== 'all') {
    params.push(cleanCity);
    conditions.push(`(LOWER(d.city) = $${params.length} OR d.city IS NULL OR LOWER(d.city) = 'all' OR LOWER(d.city) = '')`);
  }
  if (cleanState && cleanState !== 'all') {
    params.push(cleanState);
    conditions.push(`(LOWER(d.state) = $${params.length} OR d.state IS NULL OR LOWER(d.state) = 'all' OR LOWER(d.state) = '')`);
  }

  if (conditions.length > 0) {
    query += ` WHERE ${conditions.join(' AND ')}`;
  }

  if (cleanCity && cleanCity !== 'all') {
    query += ` ORDER BY CASE WHEN LOWER(d.city) = $1 THEN 0 ELSE 1 END, d.created_at DESC LIMIT 50`;
  } else {
    query += ` ORDER BY d.created_at DESC LIMIT 50`;
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

    return res.status(201).json({ deal: { ...rows[0], redemptions_count: 0 } });
  } catch (error) {
    console.error('Error creating deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.updateDeal = async (req, res) => {
  try {
    const dealId = req.params.id;
    let { title, description, discount_code, banner_url, city, state } = req.body;

    if (req.file) {
      banner_url = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    if (!title || !description) {
      return res.status(400).json({ error: 'Title and description are required' });
    }

    const { rows } = await db.query(
      `UPDATE deals
       SET title = $1,
           description = $2,
           discount_code = $3,
           city = $4,
           state = $5,
           banner_url = COALESCE($6, banner_url)
       WHERE id = $7
       RETURNING *`,
      [
        title.trim(),
        description.trim(),
        discount_code ? discount_code.trim() : null,
        city && city.trim() ? city.trim() : null,
        state && state.trim() ? state.trim() : null,
        banner_url !== undefined && banner_url !== null && banner_url.trim() !== '' ? banner_url.trim() : null,
        dealId
      ]
    );

    if (!rows.length) return res.status(404).json({ error: 'Deal not found' });

    // Fetch redemptions count
    const { rows: countRows } = await db.query(
      'SELECT COUNT(*)::int AS redemptions_count FROM deal_redemptions WHERE deal_id = $1',
      [dealId]
    );

    await invalidateAndWarmDeals();
    return res.json({ deal: { ...rows[0], redemptions_count: countRows[0]?.redemptions_count ?? 0 } });
  } catch (error) {
    console.error('Error updating deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteDeal = async (req, res) => {
  try {
    const isPermanent = req.query.permanent === 'true';

    if (isPermanent) {
      const { rows } = await db.query(
        'DELETE FROM deals WHERE id = $1 RETURNING id',
        [req.params.id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Deal not found' });
    } else {
      const { rows } = await db.query(
        'UPDATE deals SET is_deleted = true, deleted_at = NOW() WHERE id = $1 RETURNING id, deleted_at',
        [req.params.id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Deal not found' });
    }

    await invalidateAndWarmDeals();
    return res.json({ deleted: req.params.id, permanent: isPermanent });
  } catch (error) {
    console.error('Error deleting deal:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.restoreDeal = async (req, res) => {
  try {
    const { rows } = await db.query(
      'UPDATE deals SET is_deleted = false, deleted_at = NULL WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Deal not found' });

    await invalidateAndWarmDeals();
    return res.json({ restored: true, deal: rows[0] });
  } catch (error) {
    console.error('Error restoring deal:', error);
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

exports.getAdminDeals = async (req, res) => {
  try {
    res.setHeader('Cache-Control', 'private, no-store');

    const { rows: activeRows } = await db.query(`
      SELECT d.id, d.title, d.description, d.discount_code, d.banner_url, d.city, d.state, d.created_at,
        COALESCE(r.redemptions_count, 0)::int AS redemptions_count
      FROM deals d
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS redemptions_count
        FROM deal_redemptions dr
        WHERE dr.deal_id = d.id
      ) r ON TRUE
      WHERE COALESCE(d.is_deleted, false) = false
      ORDER BY d.created_at DESC
    `);

    const { rows: historyRows } = await db.query(`
      SELECT d.id, d.title, d.description, d.discount_code, d.banner_url, d.city, d.state, d.created_at, d.deleted_at,
        COALESCE(r.redemptions_count, 0)::int AS redemptions_count
      FROM deals d
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS redemptions_count
        FROM deal_redemptions dr
        WHERE dr.deal_id = d.id
      ) r ON TRUE
      WHERE d.is_deleted = true
      ORDER BY d.deleted_at DESC NULLS LAST, d.created_at DESC
    `);

    return res.json({
      deals: activeRows,
      history: historyRows,
      total_active: activeRows.length,
      total_history: historyRows.length,
    });
  } catch (error) {
    console.error('Error fetching admin deals:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getDealRedemptions = async (req, res) => {
  try {
    const dealId = req.params.id;
    const { rows } = await db.query(
      `SELECT
         dr.id,
         dr.deal_id,
         dr.user_id,
         dr.redeemed_at,
         COALESCE(u.name, 'Student') AS name,
         COALESCE(u.email, '') AS email,
         COALESCE(u.campus_id, '') AS campus_id,
         COALESCE(u.deal_code, '') AS deal_code,
         COALESCE(u.college, '') AS college,
         COALESCE(u.branch, '') AS branch,
         COUNT(*) OVER()::int AS total
       FROM deal_redemptions dr
       INNER JOIN users u ON u.id = dr.user_id
       WHERE dr.deal_id = $1
       ORDER BY dr.redeemed_at DESC
       LIMIT 1000`,
      [dealId]
    );

    return res.json({
      redemptions: rows,
      total: rows[0]?.total ?? 0,
      limit: 1000,
    });
  } catch (error) {
    console.error('Error fetching deal redemptions:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
