// backend/src/config/redis.js
const Redis = require('ioredis');

let client = null;
let isReady = false;

function resolveRedisUrl() {
  if (process.env.REDIS_URL) return process.env.REDIS_URL;
  if (process.env.REDIS_PRIVATE_URL) return process.env.REDIS_PRIVATE_URL;
  if (process.env.REDIS_TLS_URL) return process.env.REDIS_TLS_URL;
  if (process.env.REDISHOST) {
    const user = process.env.REDISUSER || 'default';
    const pass = process.env.REDISPASSWORD ? `:${encodeURIComponent(process.env.REDISPASSWORD)}@` : '';
    const port = process.env.REDISPORT || 6379;
    return `redis://${user}${pass}${process.env.REDISHOST}:${port}`;
  }
  return null;
}

const connectionUrl = resolveRedisUrl();

if (connectionUrl) {
  try {
    const isTls = connectionUrl.startsWith('rediss://');
    client = new Redis(connectionUrl, {
      maxRetriesPerRequest: 2,
      enableOfflineQueue: false,
      connectTimeout: 5000,
      retryStrategy(times) {
        // Exponential backoff reconnect: 100ms, 200ms, ... up to 3s
        return Math.min(times * 100, 3000);
      },
      tls: isTls ? { rejectUnauthorized: false } : undefined,
    });

    client.on('connect', () => {
      console.log('🔌 Redis connecting...');
    });

    client.on('ready', () => {
      isReady = true;
      console.log('✅ Redis connected and ready for instant caching');
    });

    client.on('error', (err) => {
      isReady = false;
      // Do NOT set client = null! Let ioredis auto-reconnect.
      console.warn('⚠️  Redis connection warning:', err.message);
    });

    client.on('close', () => {
      isReady = false;
    });

    client.on('reconnecting', () => {
      console.log('🔄 Redis reconnecting...');
    });
  } catch (e) {
    console.warn('⚠️  Redis init failed (caching disabled):', e.message);
    client = null;
    isReady = false;
  }
} else {
  console.log('ℹ️  REDIS_URL not set — caching running in memory mode');
}

module.exports = {
  get redis() { return client; },
  get isConnected() { return isReady; },

  async getCache(key) {
    if (!client || !isReady) return null;
    try {
      return await client.get(key);
    } catch {
      return null;
    }
  },

  async setCache(key, value, ttlSeconds = 60) {
    if (!client || !isReady) return;
    try {
      await client.set(key, value, 'EX', ttlSeconds);
    } catch {}
  },

  async delCache(...keys) {
    if (!client || !isReady || !keys.length) return;
    try {
      const valid = keys.filter(Boolean);
      if (valid.length) await client.del(...valid);
    } catch {}
  },

  async delPattern(pattern) {
    if (!client || !isReady) return;
    try {
      // Use SCAN to safely find matching keys without freezing Redis
      let cursor = '0';
      do {
        const [nextCursor, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
        cursor = nextCursor;
        if (keys && keys.length) {
          await client.del(...keys);
        }
      } while (cursor !== '0');
    } catch {}
  },
};
