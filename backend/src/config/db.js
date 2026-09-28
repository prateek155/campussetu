// backend/src/config/db.js
// PostgreSQL connection pool — optimized for PM2 cluster + Neon serverless
const { Pool } = require('pg');

// When running under PM2 cluster, each worker gets its own pool.
// Total connections = max × workers. Keep max low to avoid Neon limits.
// Neon free tier: 25 connections total.
// 4 workers × 5 = 20 connections (safe), production × 3 = 15 (safe).
const isProduction = process.env.NODE_ENV === 'production';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: isProduction ? { rejectUnauthorized: false } : false,

  // Per-worker pool settings
  max: isProduction ? 5 : 10,     // 5 per worker × 4 workers = 20 total on prod
  min: 1,                          // keep at least 1 connection warm
  idleTimeoutMillis: 30_000,       // release idle connections after 30s
  connectionTimeoutMillis: 5_000,  // fail fast if DB unreachable
  keepAlive: true,
  keepAliveInitialDelayMillis: 10_000,
});

// Log pool stats every 5 minutes in production for monitoring
if (isProduction) {
  setInterval(() => {
    console.log(`[DB Pool] total=${pool.totalCount} idle=${pool.idleCount} waiting=${pool.waitingCount}`);
  }, 5 * 60 * 1000);
}

pool.on('error', (err) => {
  // Neon closes idle connections (57P01) — normal, pool will reconnect
  if (err.code === '57P01') {
    console.warn('[DB] Neon closed idle connection — will reconnect automatically');
    return;
  }
  console.warn('[DB] Pool error:', err.code, err.message);
});

pool.on('connect', () => {
  if (!isProduction) console.log('[DB] New connection established');
});

/**
 * Helper: run a query with automatic retry on connection errors.
 * Useful for transient Neon "endpoint is starting" errors.
 */
const originalQuery = pool.query.bind(pool);
pool.query = async function retryQuery(...args) {
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      return await originalQuery(...args);
    } catch (err) {
      lastErr = err;
      // Retry only on connection/socket errors, not SQL errors
      const retryable = ['ECONNRESET', 'ENOTFOUND', 'ETIMEDOUT', '57P01', '08006', '08001'];
      if (retryable.includes(err.code) && attempt < 3) {
        await new Promise(r => setTimeout(r, attempt * 500));
        continue;
      }
      throw err;
    }
  }
  throw lastErr;
};

module.exports = pool;
