// backend/src/middleware/auth.js
const admin = require('../config/firebase');
const cache = require('../config/redis');
const { activityLogger } = require('./activityLogger');

// In-memory fallback cache when Redis is unavailable
const _memCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 min
const CACHE_TTL_SEC = 5 * 60;       // 5 min (for Redis EX)

function continueAuthenticatedRequest(req, res, next, decoded) {
  req.user = decoded;
  if (res.locals.activityLoggingAttached) return next();
  res.locals.activityLoggingAttached = true;
  return activityLogger(req, res, next);
}

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
    if (cached) {
      return continueAuthenticatedRequest(req, res, next, cached);
    }

    const decoded = await admin.auth().verifyIdToken(idToken, true);
    await setCachedToken(idToken, decoded);
    return continueAuthenticatedRequest(req, res, next, decoded);
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
    console.error('requireAdmin error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const requireEnterprise = async (req, res, next) => {
  try {
    const { customClaims } = await admin.auth().getUser(req.user.uid);
    if (customClaims?.admin || customClaims?.enterprise) {
      return next();
    }
    const { rows } = await db.query('SELECT is_admin, is_enterprise FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (rows.length > 0 && (rows[0].is_admin === true || rows[0].is_enterprise === true)) {
      return next();
    }
    return res.status(403).json({ error: 'Forbidden: Enterprise access required' });
  } catch (err) {
    console.error('requireEnterprise error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const requireFaculty = async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT role, is_admin FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (rows.length > 0 && (rows[0].role === 'faculty' || rows[0].is_admin === true)) {
      return next();
    }
    return res.status(403).json({ error: 'Forbidden: Faculty access required' });
  } catch (err) {
    console.error('requireFaculty error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { requireAuth, requireAdmin, requireEnterprise, requireFaculty };
