// backend/src/config/redis.js
const Redis = require('ioredis');
const { randomUUID } = require('crypto');

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
      lazyConnect: false,
      retryStrategy(times) {
        if (times > 10) return null; // stop retrying after 10 attempts
        return Math.min(times * 200, 5000); // exponential backoff up to 5s
      },
      tls: isTls ? {} : undefined,
    });

    client.on('connect', () => console.log('🔌 Redis connecting...'));
    client.on('ready', () => { isReady = true; console.log('✅ Redis connected and ready'); });
    client.on('error', (err) => { isReady = false; console.warn('⚠️  Redis error:', err.message); });
    client.on('close', () => { isReady = false; });
    client.on('reconnecting', () => console.log('🔄 Redis reconnecting...'));
  } catch (e) {
    console.warn('⚠️  Redis init failed (caching disabled):', e.message);
    client = null;
    isReady = false;
  }
} else {
  console.log('ℹ️  REDIS_URL not set — Redis-backed caches are disabled');
}

// ── TTL Constants ─────────────────────────────────────────────────────────────
const TTL = {
  USER_PROFILE: 10 * 60,       // 10 minutes
  USER_POINTS:   5 * 60,       // 5 minutes
  USER_AVATAR:  30 * 60,       // 30 minutes
  FEED_PAGE:     2 * 60,       // 2 minutes
  LEADERBOARD:   5 * 60,       // 5 minutes
  QUIZ_ROOM:   120 * 60,       // 2 hours
  SEARCH:        1 * 60,       // 1 minute
  SHORT:            30,        // 30 seconds
};

// ── Key Helpers ───────────────────────────────────────────────────────────────
const KEYS = {
  userProfile:      (uid)           => `user:profile:${uid}`,
  userPoints:       (uid)           => `user:points:${uid}`,
  userAvatar:       (uid)           => `user:avatar:${uid}`,
  feedPage:         (uniId, page)   => `feed:uni:${uniId}:page:${page}`,
  leaderboard:      ()              => `leaderboard:top50`,
  quizRoom:         (quizId)        => `quiz:room:${quizId}`,
  quizParticipants: (quizId)        => `quiz:participants:${quizId}`,
  search:           (type, q)       => `search:${type}:${q}`,
};

// ── Core Cache Methods ────────────────────────────────────────────────────────

async function getCache(key) {
  if (!client || !isReady) return null;
  try {
    return await client.get(key);
  } catch {
    return null;
  }
}

async function setCache(key, value, ttlSeconds = 60) {
  if (!client || !isReady) return;
  try {
    await client.set(key, value, 'EX', ttlSeconds);
  } catch {}
}

async function delCache(...keys) {
  if (!client || !isReady || !keys.length) return;
  try {
    const valid = keys.filter(Boolean);
    if (valid.length) await client.del(...valid);
  } catch {}
}

async function delPattern(pattern) {
  if (!client || !isReady) return;
  try {
    let cursor = '0';
    do {
      const [nextCursor, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = nextCursor;
      if (keys && keys.length) await client.del(...keys);
    } while (cursor !== '0');
  } catch {}
}

// ── JSON Helpers (most cached values are JSON objects) ────────────────────────

async function getJson(key) {
  const raw = await getCache(key);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

async function setJson(key, value, ttlSeconds = 60) {
  await setCache(key, JSON.stringify(value), ttlSeconds);
}

async function invalidateJson(key) {
  if (!client || !isReady || !key) return;
  try {
    const versionKey = `cache-version:${key}`;
    await client.multi()
      .incr(versionKey)
      .pexpire(versionKey, 24 * 60 * 60 * 1000)
      .del(key)
      .exec();
  } catch {}
}

async function getJsonVersion(key) {
  if (!client || !isReady) return null;
  try {
    return (await client.get(`cache-version:${key}`)) || '0';
  } catch {
    return null;
  }
}

async function setJsonIfVersionUnchanged(key, value, ttlSeconds, version) {
  const currentVersion = await getJsonVersion(key);
  if (currentVersion !== version) {
    const currentValue = await getJson(key);
    return currentValue === null ? value : currentValue;
  }
  await setJson(key, value, ttlSeconds);
  return value;
}

const localLoads = new Map();

/**
 * Read-through JSON cache with per-process single-flight and a short Redis
 * lease, so concurrent cold/expired reads do not all query PostgreSQL.
 * If Redis is unavailable, the loader still runs and the endpoint remains
 * available through its normal database path.
 */
async function getOrLoadJson(key, ttlSeconds, loader) {
  const cached = await getJson(key);
  if (cached !== null) return cached;

  if (localLoads.has(key)) return localLoads.get(key);

  const pending = (async () => {
    if (!client || !isReady) return loader();

    const lockKey = `cache-lock:${key}`;
    const token = randomUUID();
    let ownsLock = false;
    try {
      ownsLock = (await client.set(lockKey, token, 'PX', 10000, 'NX')) === 'OK';
    } catch {
      return loader();
    }

    if (!ownsLock) {
      for (let attempt = 0; attempt < 20; attempt += 1) {
        await new Promise((resolve) => setTimeout(resolve, 75));
        const value = await getJson(key);
        if (value !== null) return value;
        if (!isReady) return loader();
      }
      // A slow DB query should not make this request wait indefinitely.
      const version = await getJsonVersion(key);
      const value = await loader();
      return setJsonIfVersionUnchanged(key, value, ttlSeconds, version);
    }

    try {
      const valueAfterLock = await getJson(key);
      if (valueAfterLock !== null) return valueAfterLock;
      const version = await getJsonVersion(key);
      const value = await loader();
      return setJsonIfVersionUnchanged(key, value, ttlSeconds, version);
    } finally {
      try {
        await client.eval(
          "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
          1,
          lockKey,
          token,
        );
      } catch {}
    }
  })();

  localLoads.set(key, pending);
  try {
    return await pending;
  } finally {
    if (localLoads.get(key) === pending) localLoads.delete(key);
  }
}

// ── User-specific helpers ─────────────────────────────────────────────────────

/** Get full cached user profile. Returns object or null. */
async function getUserProfile(uid) {
  return getJson(KEYS.userProfile(uid));
}

/** Cache full user profile (call after DB fetch or update). */
async function setUserProfile(uid, profileObj) {
  await setJson(KEYS.userProfile(uid), profileObj, TTL.USER_PROFILE);
  // Also cache avatar URL separately for quick lookup
  if (profileObj.profile_picture) {
    await setCache(KEYS.userAvatar(uid), profileObj.profile_picture, TTL.USER_AVATAR);
  }
}

/** Invalidate all user-related caches (call on profile update). */
async function invalidateUser(uid) {
  await Promise.all([
    invalidateJson(KEYS.userProfile(uid)),
    delCache(KEYS.userPoints(uid), KEYS.userAvatar(uid)),
  ]);
}

/** Get cached points. Returns number or null. */
async function getUserPoints(uid) {
  const raw = await getCache(KEYS.userPoints(uid));
  return raw !== null ? parseInt(raw, 10) : null;
}

/** Cache user points. */
async function setUserPoints(uid, points) {
  await setCache(KEYS.userPoints(uid), String(points), TTL.USER_POINTS);
}

/** Atomically increment cached points (avoids stale read-modify-write). */
async function incrUserPoints(uid, amount) {
  if (!client || !isReady) return;
  try {
    const key = KEYS.userPoints(uid);
    const exists = await client.exists(key);
    if (exists) {
      await client.incrby(key, amount);
    }
    // If key doesn't exist, don't cache partial data — let next read populate it
  } catch {}
}

// ── Leaderboard helpers ───────────────────────────────────────────────────────

async function getLeaderboard() {
  return getJson(KEYS.leaderboard());
}

async function setLeaderboard(rows) {
  await setJson(KEYS.leaderboard(), rows, TTL.LEADERBOARD);
}

async function invalidateLeaderboard() {
  await delCache(KEYS.leaderboard());
}

// ── Feed helpers ──────────────────────────────────────────────────────────────

async function getFeedPage(uniId, page) {
  return getJson(KEYS.feedPage(uniId, page));
}

async function setFeedPage(uniId, page, posts) {
  await setJson(KEYS.feedPage(uniId, page), posts, TTL.FEED_PAGE);
}

/** Invalidate feed for a university (on new post). */
async function invalidateFeed(uniId) {
  await delPattern(`feed:uni:${uniId}:*`);
}

// ── Quiz helpers ──────────────────────────────────────────────────────────────

async function getQuizRoom(quizId) {
  return getJson(KEYS.quizRoom(quizId));
}

async function setQuizRoom(quizId, roomData) {
  await setJson(KEYS.quizRoom(quizId), roomData, TTL.QUIZ_ROOM);
}

async function invalidateQuiz(quizId) {
  await delCache(KEYS.quizRoom(quizId), KEYS.quizParticipants(quizId));
}

// ── Pipeline helper (batch multiple sets efficiently) ─────────────────────────

/**
 * Run multiple Redis commands in a single round-trip.
 * Usage: pipeline(pipe => { pipe.set('k1','v1','EX',60); pipe.set('k2','v2','EX',120); })
 */
async function pipeline(fn) {
  if (!client || !isReady) return;
  try {
    const pipe = client.pipeline();
    fn(pipe);
    await pipe.exec();
  } catch {}
}

// ── Module exports ────────────────────────────────────────────────────────────

module.exports = {
  get redis() { return client; },
  get isConnected() { return isReady; },

  // TTL constants & key helpers (useful for custom cache logic in controllers)
  TTL,
  KEYS,

  // Core primitives
  getCache,
  setCache,
  delCache,
  delPattern,
  getJson,
  setJson,
  invalidateJson,
  getOrLoadJson,
  pipeline,

  // User profile caching
  getUserProfile,
  setUserProfile,
  invalidateUser,
  getUserPoints,
  setUserPoints,
  incrUserPoints,

  // Leaderboard caching
  getLeaderboard,
  setLeaderboard,
  invalidateLeaderboard,

  // Feed caching
  getFeedPage,
  setFeedPage,
  invalidateFeed,

  // Quiz room caching
  getQuizRoom,
  setQuizRoom,
  invalidateQuiz,
};
