// backend/src/config/db.js
// PostgreSQL connection pool
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  min: 2,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 2000,
  keepAlive: true,
});

pool.on('error', (err) => {
  if (err.code === '57P01') {
    console.warn('DB pool: Neon closed idle connection (57P01) — will reconnect');
    return;
  }
  console.warn('DB pool warning:', err.code, err.message);
});

module.exports = pool;
