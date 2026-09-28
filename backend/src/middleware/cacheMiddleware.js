// backend/src/middleware/cacheMiddleware.js
//
// Drop-in Express middleware for automatic response caching.
//
// Usage:
//   const { cacheRoute, invalidateCache } = require('../middleware/cacheMiddleware');
//
//   // Cache GET /api/v1/events for 2 minutes:
//   router.get('/', requireAuth, cacheRoute(120), eventsController.list);
//
//   // Invalidate on POST:
//   router.post('/', requireAuth, invalidateCache('events:*'), eventsController.create);

const cache = require('../config/redis');

/**
 * Middleware: serve cached response if available, else cache the response.
 * @param {number} ttl - seconds to cache
 * @param {(req) => string} [keyFn] - custom key generator, defaults to route + query
 */
function cacheRoute(ttl = 60, keyFn) {
  return async (req, res, next) => {
    const key = keyFn
      ? keyFn(req)
      : `route:${req.path}:${JSON.stringify(req.query)}`;

    const cached = await cache.getCache(key);
    if (cached) {
      try {
        res.setHeader('X-Cache', 'HIT');
        return res.json(JSON.parse(cached));
      } catch { /* fall through */ }
    }

    // Monkey-patch res.json to cache the response before sending
    const originalJson = res.json.bind(res);
    res.json = async (data) => {
      res.setHeader('X-Cache', 'MISS');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await cache.setCache(key, JSON.stringify(data), ttl);
      }
      return originalJson(data);
    };

    next();
  };
}

/**
 * Middleware: delete cache keys matching pattern(s) after a mutating request succeeds.
 * @param {...string} patterns - glob patterns (e.g. 'events:*', 'feed:*')
 */
function invalidateCache(...patterns) {
  return async (req, res, next) => {
    const originalJson = res.json.bind(res);
    res.json = async (data) => {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await Promise.all(patterns.map(p => cache.delPattern(p)));
      }
      return originalJson(data);
    };
    next();
  };
}

/**
 * User-specific cache key helper.
 * Returns a function that generates: "route:<path>:uid:<firebase_uid>:<query>"
 */
function userKey(req) {
  return `route:${req.path}:uid:${req.user?.uid}:${JSON.stringify(req.query)}`;
}

module.exports = { cacheRoute, invalidateCache, userKey };
