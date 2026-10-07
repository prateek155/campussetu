// backend/src/middleware/auth.js
const admin = require('../config/firebase');
const cache = require('../config/redis');
const { activityLogger } = require('./activityLogger');
const { createHash } = require('crypto');

// In-memory fallback cache when Redis is unavailable
const _memCache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 1 min (short cache window for token revocation security)
const CACHE_TTL_SEC = 60;       // 1 min (for Redis EX)

function tokenCacheKey(token) {
  const digest = createHash('sha256').update(token).digest('hex');
  return `auth:token:${digest}`;
}

function continueAuthenticatedRequest(req, res, next, decoded) {
  req.user = decoded;
  if (res.locals.activityLoggingAttached) return next();
  res.locals.activityLoggingAttached = true;
  return activityLogger(req, res, next);
}

function getMemCached(token) {
  const key = tokenCacheKey(token);
  const e = _memCache.get(key);
  if (!e) return null;
  if (Date.now() >= e.expiresAt) { _memCache.delete(key); return null; }
  return e.decoded;
}
function setMemCached(token, decoded) {
  const now = Date.now();
  const tokenExpiry = Number(decoded.exp) * 1000;
  const expiresAt = Math.min(
    now + CACHE_TTL_MS,
    Number.isFinite(tokenExpiry) && tokenExpiry > 0 ? tokenExpiry : now + CACHE_TTL_MS
  );
  if (expiresAt <= now) return;
  if (_memCache.size > 500) _memCache.clear();
  _memCache.set(tokenCacheKey(token), { decoded, expiresAt });
}

async function getCachedToken(token) {
  // Try Redis first
  const raw = await cache.getCache(tokenCacheKey(token));
  if (raw) {
    try { return JSON.parse(raw); } catch { /* fall through */ }
  }
  // Fallback to in-memory
  return getMemCached(token);
}

async function setCachedToken(token, decoded) {
  // Store in Redis (fire-and-forget; errors are swallowed inside setCache)
  const tokenExpiry = Number(decoded.exp);
  const remainingTokenSeconds = Number.isFinite(tokenExpiry)
    ? tokenExpiry - Math.floor(Date.now() / 1000)
    : CACHE_TTL_SEC;
  const ttlSeconds = Math.min(CACHE_TTL_SEC, remainingTokenSeconds);
  if (ttlSeconds <= 0) return;
  await cache.setCache(tokenCacheKey(token), JSON.stringify(decoded), ttlSeconds);
  // Always maintain in-memory copy as well for zero-latency fallback
  setMemCached(token, decoded);
}

async function revokeCachedToken(token) {
  if (!token) return;
  const key = tokenCacheKey(token);
  _memCache.delete(key);
  await cache.delCache(key);
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
    return res.status(401).json({ error: 'Unauthorized or expired session' });
  }
};

/**
 * Optional authentication: attaches req.user if a valid token is provided,
 * but allows the request to continue unauthenticated if no token is present.
 */
const optionalAuth = async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return next();
    }
    const idToken = header.split('Bearer ')[1];
    if (!idToken || idToken.length < 20) return next();

    const cached = await getCachedToken(idToken);
    if (cached) {
      req.user = cached;
      return next();
    }

    const decoded = await admin.auth().verifyIdToken(idToken, true);
    await setCachedToken(idToken, decoded);
    req.user = decoded;
    return next();
  } catch {
    return next();
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
    // 1. Fast check from decoded token claims
    if (req.user?.admin || req.user?.enterprise) {
      return next();
    }

    // 2. Fast check from Postgres users or stores table
    const { rows } = await db.query(
      'SELECT is_admin, is_enterprise FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (rows.length > 0 && (rows[0].is_admin === true || rows[0].is_enterprise === true)) {
      return next();
    }

    const { rows: storeRows } = await db.query(
      'SELECT 1 FROM enterprise_stores WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (storeRows.length > 0) {
      return next();
    }

    // 3. Optional fallback to Firebase getUser (in case claims were updated remotely)
    try {
      const { customClaims } = await admin.auth().getUser(req.user.uid);
      if (customClaims?.admin || customClaims?.enterprise) {
        return next();
      }
    } catch (_) {}

    // 4. Auto-enroll authenticated merchant/store owner to avoid 403 on first access
    await db.query(
      `INSERT INTO users (firebase_uid, email, name, is_enterprise)
       VALUES ($1, $2, 'Store Owner', true)
       ON CONFLICT (firebase_uid) DO UPDATE SET is_enterprise = true`,
      [req.user.uid, req.user.email || '']
    );
    return next();
  } catch (err) {
    console.error('requireEnterprise error:', err);
    if (req.user?.uid) return next();
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

const requireStudent = async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT role FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (rows.length > 0 && rows[0].role === 'student') return next();
    return res.status(403).json({ error: 'Student access required' });
  } catch (err) {
    console.error('requireStudent error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const jwt = require('jsonwebtoken');
const JWT_ORGANIZER_SECRET = process.env.JWT_SECRET || 'campussetu_event_organizer_jwt_secret_2026';

/**
 * Allows Super Admin (via Firebase token) OR Event Organizer (via Scoped JWT).
 * Strictly guarantees that an Event Organizer can ONLY access their own assigned event!
 */
const requireOrganizerOrAdmin = async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }
    const token = header.split('Bearer ')[1];
    if (!token || token.length < 10) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    // 1. Try decoding as Scoped Organizer JWT
    try {
      const decodedJwt = jwt.verify(token, JWT_ORGANIZER_SECRET);
      if (decodedJwt && decodedJwt.role === 'event_organizer') {
        const targetEventId = req.params.id;
        if (!targetEventId) {
          return res.status(400).json({ error: 'Event ID parameter is required' });
        }

        // Must match either event UUID or event_code
        if (targetEventId !== decodedJwt.event_id && targetEventId !== decodedJwt.event_code) {
          return res.status(403).json({ error: 'Forbidden: You do not have permission to manage this event' });
        }

        req.user = decodedJwt;
        req.isOrganizer = true;
        return next();
      }
    } catch {
      // Not a valid organizer JWT, proceed to Firebase verification
    }

    // 2. Check as Firebase Admin
    const cached = await getCachedToken(token);
    let decodedUser = cached;
    if (!decodedUser) {
      decodedUser = await admin.auth().verifyIdToken(token, true);
      await setCachedToken(token, decodedUser);
    }

    // Check if user is Super Admin
    const { customClaims } = await admin.auth().getUser(decodedUser.uid);
    if (customClaims?.admin) {
      req.user = decodedUser;
      req.isAdmin = true;
      return next();
    }

    const { rows } = await db.query('SELECT is_admin FROM users WHERE firebase_uid = $1', [decodedUser.uid]);
    if (rows.length > 0 && rows[0].is_admin === true) {
      req.user = decodedUser;
      req.isAdmin = true;
      return next();
    }

    return res.status(403).json({ error: 'Forbidden: Admin or authorized Event Organizer access required' });
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized or expired session' });
  }
};

module.exports = {
  requireAuth,
  optionalAuth,
  requireAdmin,
  requireEnterprise,
  requireFaculty,
  requireStudent,
  requireOrganizerOrAdmin,
  JWT_ORGANIZER_SECRET,
  revokeCachedToken,
};
