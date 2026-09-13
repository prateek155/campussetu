// backend/src/config/redis.js
const Redis = require('ioredis');

let client = null;

if (process.env.REDIS_URL) {
  try {
    client = new Redis(process.env.REDIS_URL, {
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      lazyConnect: true,
      connectTimeout: 3000,
    });
    client.on('connect', () => console.log('✅ Redis connected'));
    client.on('error', (err) => {
      console.warn('⚠️  Redis error (caching disabled):', err.message);
      client = null;
    });
  } catch (e) {
    console.warn('⚠️  Redis init failed (caching disabled):', e.message);
    client = null;
  }
} else {
  console.log('ℹ️  REDIS_URL not set — caching disabled');
}

module.exports = {
  get redis() { return client; },

  async getCache(key) {
    if (!client) return null;
    try { return await client.get(key); } catch { return null; }
  },

  async setCache(key, value, ttlSeconds = 60) {
    if (!client) return;
    try { await client.set(key, value, 'EX', ttlSeconds); } catch {}
  },

  async delCache(...keys) {
    if (!client) return;
    try { await client.del(...keys); } catch {}
  },

  async delPattern(pattern) {
    if (!client) return;
    try {
      const keys = await client.keys(pattern);
      if (keys.length) await client.del(...keys);
    } catch {}
  },
};
