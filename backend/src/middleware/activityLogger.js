// src/middleware/activityLogger.js
// Real-time activity monitoring with suspicious behaviour detection

// ── In-memory circular buffer ──────────────────────────────
const _events = [];
const MAX_EVENTS = 500;

// ── Suspicious activity tracker ───────────────────────────
// userId -> { actions: [], risk: 'LOW'|'MEDIUM'|'HIGH', ... }
const _suspiciousMap = new Map();

// ── Core helpers ──────────────────────────────────────────

function addEvent(type, userName, action, userId) {
  const event = {
    id: Date.now() + Math.random(),
    type,
    user_name: userName,
    action,
    user_id: userId,
    created_at: new Date().toISOString(),
  };
  _events.unshift(event);
  if (_events.length > MAX_EVENTS) _events.pop();
  trackSuspicious(userId, type, action, userName);
}

function trackSuspicious(userId, type, action, userName) {
  if (!userId) return;
  const now = Date.now();

  if (!_suspiciousMap.has(userId)) {
    _suspiciousMap.set(userId, {
      user_id: userId,
      user_name: userName,
      actions: [],
      risk: 'LOW',
      first_seen: now,
    });
  }

  const entry = _suspiciousMap.get(userId);
  entry.actions.push({ type, action, ts: now });

  // Keep only the last 5 minutes of actions
  entry.actions = entry.actions.filter((a) => now - a.ts < 5 * 60 * 1000);

  // ── Risk scoring ─────────────────────────────────────────
  const recentMinute = entry.actions.filter((a) => now - a.ts < 60_000);
  const recentPoints = recentMinute.filter((a) => a.type === 'points');
  const recentAdmin = recentMinute.filter((a) => a.type === 'admin_attempt');
  const recentConnects = recentMinute.filter((a) => a.type === 'connect');
  const recentProfiles = entry.actions.filter(
    (a) => now - a.ts < 30_000 && a.type === 'profile_view'
  );

  let score = 0;
  if (recentPoints.length >= 5) score += 60;   // 5+ transfers in 60 s
  if (recentAdmin.length >= 1) score += 40;    // any admin attempt
  if (recentConnects.length >= 20) score += 30;
  if (recentProfiles.length >= 10) score += 20;

  if (score >= 60) entry.risk = 'HIGH';
  else if (score >= 30) entry.risk = 'MEDIUM';
  else entry.risk = 'LOW';

  entry.score = score;
  entry.user_name = userName;
  entry.updated_at = now;
  _suspiciousMap.set(userId, entry);
}

// Prune LOW-risk, stale entries every 10 minutes
setInterval(() => {
  const now = Date.now();
  for (const [uid, entry] of _suspiciousMap.entries()) {
    if (entry.risk === 'LOW' && now - entry.updated_at > 10 * 60 * 1000) {
      _suspiciousMap.delete(uid);
    }
  }
}, 10 * 60 * 1000);

// ── Public API ────────────────────────────────────────────

exports.getLiveFeed = (limit = 20) => _events.slice(0, limit);

exports.getPulseStats = () => {
  const recent = _events.slice(0, 100);
  const total = recent.length || 1;
  const counts = { post: 0, points: 0, chat: 0, connect: 0, flagged: 0 };
  recent.forEach((e) => {
    if (counts[e.type] !== undefined) counts[e.type]++;
  });
  return {
    feed_pct: Math.round((counts.post / total) * 100),
    wallet_pct: Math.round((counts.points / total) * 100),
    chat_pct: Math.round((counts.chat / total) * 100),
    connect_pct: Math.round((counts.connect / total) * 100),
    flagged_pct: Math.round((counts.flagged / total) * 100),
    total_events: _events.length,
    active_users: new Set(
      _events.slice(0, 100).map((e) => e.user_id).filter(Boolean)
    ).size,
  };
};

exports.getSuspiciousActivities = () => {
  const result = [];
  for (const [uid, entry] of _suspiciousMap.entries()) {
    if (entry.risk === 'MEDIUM' || entry.risk === 'HIGH') {
      const now = Date.now();
      const timeWindow =
        entry.actions.length > 1
          ? Math.round((now - entry.actions[entry.actions.length - 1].ts) / 1000)
          : 0;
      const pointActions = entry.actions.filter((a) => a.type === 'points');
      const accountsTouched = new Set(pointActions.map((a) => a.to_user)).size;
      result.push({
        id: uid,
        user_id: uid,
        user_name: entry.user_name,
        risk_level: entry.risk,
        accounts_touched: accountsTouched || pointActions.length,
        time_window_s: timeWindow,
        points_moved: pointActions.length * 100, // approximate
        recent_actions: entry.actions
          .slice(-6)
          .reverse()
          .map((a) => ({
            type: a.type,
            action: a.action,
            ago_s: Math.round((now - a.ts) / 1000),
          })),
      });
    }
  }
  return result.sort((a, b) => b.risk_level.localeCompare(a.risk_level));
};

exports.dismissActivity = (userId) => {
  _suspiciousMap.delete(userId);
};

exports.addEvent = addEvent;

// ── Express middleware ────────────────────────────────────

exports.activityLogger = (req, res, next) => {
  res.on('finish', () => {
    const path = req.path;
    const uid = req.user?.uid;
    const method = req.method;

    // Track admin-access attempts that were rejected
    if (
      path.includes('/admin') &&
      res.statusCode === 403 &&
      uid
    ) {
      addEvent('admin_attempt', uid, `Tried admin: ${method} ${path}`, uid);
      return;
    }

    // Only track successful requests from authenticated users
    if (res.statusCode >= 400 || !uid) return;

    if (
      method === 'POST' &&
      (path === '/' || path.includes('/posts')) &&
      !path.includes('/comment') &&
      !path.includes('/like')
    ) {
      addEvent('post', uid, 'Created a post', uid);
    } else if (
      path.includes('/transfer') ||
      (path.includes('/points') && method === 'POST')
    ) {
      addEvent('points', uid, 'Points transfer', uid);
    } else if (path.includes('/chat') && method === 'POST') {
      addEvent('chat', uid, 'Sent a message', uid);
    } else if (
      path.includes('/connect') &&
      (path.includes('/request') || path.includes('/respond'))
    ) {
      addEvent('connect', uid, 'Connection activity', uid);
    } else if (
      method === 'GET' &&
      path.includes('/users/') &&
      path.match(/\/users\/[a-f0-9-]{36}$/)
    ) {
      addEvent('profile_view', uid, 'Viewed a profile', uid);
    }
  });
  next();
};
