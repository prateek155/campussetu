// backend/src/middleware/auth.js
const admin = require('../config/firebase');
const cache = require('../config/redis');

// In-memory fallback cache when Redis is unavailable
const _memCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 min
const CACHE_TTL_SEC = 5 * 60;       // 5 min (for Redis EX)

function getMemCached(token) {
  const e = _memCache.get(token);
  if (!e) return null;
  if (Date.now() - e.ts > CACHE_TTL_MS) { _memCache.delete(token); return null; }
  return e.decoded;
}
function setMemCached(token, decoded) {
  if (_memCache.size > 500) _memCache.clear();
  _memCache.set(token, { decoded, ts: Date.now() });
}

async function getCachedToken(token) {
  // Try Redis first
  const raw = await cache.getCache(`auth:token:${token}`);
  if (raw) {
    try { return JSON.parse(raw); } catch { /* fall through */ }
  }
  // Fallback to in-memory
  return getMemCached(token);
}

async function setCachedToken(token, decoded) {
  // Store in Redis (fire-and-forget; errors are swallowed inside setCache)
  await cache.setCache(`auth:token:${token}`, JSON.stringify(decoded), CACHE_TTL_SEC);
  // Always maintain in-memory copy as well for zero-latency fallback
  setMemCached(token, decoded);
}

/**
 * Verifies Firebase ID token from Authorization header.
 * Attaches decoded token as req.user. Cached for 5 min for speed.
 * Uses Redis when available, falls back to in-memory Map.
 */
const requireAuth = async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }
    const idToken = header.split('Bearer ')[1];
    if (!idToken || idToken.length < 20) return res.status(401).json({ error: 'Invalid token' });

    const cached = await getCachedToken(idToken);
    if (cached) { req.user = cached; return next(); }

    const decoded = await admin.auth().verifyIdToken(idToken, true);
    await setCachedToken(idToken, decoded);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: ' + err.message });
  }
};

const db = require('../config/db');

/**
 * Requires the requesting user to be an admin.
 * Must be used AFTER requireAuth.
 */
const requireAdmin = async (req, res, next) => {
  try {
    // 1. Check Firebase Custom Claims first
    const { customClaims } = await admin.auth().getUser(req.user.uid);
    if (customClaims?.admin) {
      return next();
    }
    
    // 2. Fallback: Check PostgreSQL users table
    const { rows } = await db.query('SELECT is_admin FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (rows.length > 0 && rows[0].is_admin === true) {
      return next();
    }

    return res.status(403).json({ error: 'Forbidden: Admin access required' });
  } catch (err) {
    return res.status(403).json({ error: 'Forbidden: ' + err.message });
  }
};

module.exports = { requireAuth, requireAdmin };
