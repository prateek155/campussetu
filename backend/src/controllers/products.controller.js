// backend/src/controllers/products.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

// ── GET /products ─────────────────────────────────────────
exports.getProducts = async (req, res) => {
  try {
    const { category, q, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const conditions = ["p.status = 'active'"];
    const params = [];
    let pi = 1;

    if (category) { conditions.push(`p.category = $${pi++}`); params.push(category); }
    if (q) {
      conditions.push(`(p.title ILIKE $${pi} OR p.description ILIKE $${pi})`);
      params.push(`%${q}%`); pi++;
    }

    params.push(parseInt(limit), parseInt(offset));

    const { rows } = await db.query(
      `SELECT p.*, row_to_json(u.*) AS seller
       FROM products p JOIN users u ON u.id = p.seller_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY p.created_at DESC
       LIMIT $${pi++} OFFSET $${pi}`,
      params
    );
    res.json({ data: rows, page: parseInt(page) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /products ────────────────────────────────────────
exports.createProduct = async (req, res) => {
  try {
    const { title, description, price, category } = req.body;
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      `INSERT INTO products (id, title, description, price, category, seller_id, status)
       VALUES ($1,$2,$3,$4,$5,$6,'active') RETURNING *`,
      [uuidv4(), title, description, price, category, me[0].id]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /products/:id ─────────────────────────────────────
exports.getProduct = async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT p.*, row_to_json(u.*) AS seller FROM products p JOIN users u ON u.id = p.seller_id WHERE p.id = $1',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Product not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── PATCH /products/:id/status ────────────────────────────
exports.updateProductStatus = async (req, res) => {
  try {
    const { status } = req.body; // 'active' | 'sold' | 'removed'
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      'UPDATE products SET status = $1 WHERE id = $2 AND seller_id = $3 RETURNING *',
      [status, req.params.id, me[0].id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Product not found or not authorized' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
