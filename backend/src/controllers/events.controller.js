const db = require('../config/db');
const cache = require('../config/redis');

const EVENTS_CACHE_KEY = 'events:all:v2';
const EVENTS_CACHE_TTL = 300;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value) {
  return typeof value === 'string' && UUID_RE.test(value);
}

function readText(value, maxLength) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= maxLength ? trimmed : null;
}

function normalizeExternalUrl(value) {
  if (typeof value !== 'string' || !value.trim() || value.length > 2048) return null;
  const raw = value.trim();
  const candidate = /^[a-z][a-z0-9+.-]*:\/\//i.test(raw) ? raw : `https://${raw}`;
  try {
    const url = new URL(candidate);
    if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password) return null;
    return url.toString();
  } catch {
    return null;
  }
}

async function findCurrentUserId(firebaseUid) {
  const { rows } = await db.query('SELECT id FROM users WHERE firebase_uid = $1 LIMIT 1', [firebaseUid]);
  return rows[0]?.id ?? null;
}

async function findInternalEvent(eventId) {
  const { rows } = await db.query(
    'SELECT id, registration_mode FROM events WHERE id = $1 LIMIT 1',
    [eventId]
  );
  return rows[0] ?? null;
}

async function queryEventCatalog() {
  const { rows } = await db.query(
    `SELECT e.id, e.name, e.description, e.place, e.time_date,
       COALESCE(e.registration_mode, 'external') AS registration_mode,
       e.registration_link, e.picture_url, e.created_at,
       COALESCE(r.registration_count, 0)::int AS registration_count
     FROM (
       SELECT id, name, description, place, time_date, registration_mode,
         registration_link, picture_url, created_at
       FROM events
       ORDER BY created_at DESC
       LIMIT 50
     ) e
     LEFT JOIN LATERAL (
       SELECT COUNT(*)::int AS registration_count
       FROM event_registrations er
       WHERE er.event_id = e.id
     ) r ON TRUE
     ORDER BY e.created_at DESC`
  );
  return { events: rows };
}

async function refreshEventCatalog() {
  const catalog = await queryEventCatalog();
  await cache.setCache(EVENTS_CACHE_KEY, JSON.stringify(catalog), EVENTS_CACHE_TTL);
  return catalog.events;
}

async function invalidateAndWarmEvents({ updateHomeCounts = false } = {}) {
  await cache.invalidateJson(EVENTS_CACHE_KEY);
  await cache.delCache('events:list');
  if (updateHomeCounts) await cache.delCache('home:counts');
  try {
    await refreshEventCatalog();
  } catch (error) {
    // A successful registration/event write must not turn into an API error
    // just because Redis warming could not complete.
    console.warn('[Events] cache refresh deferred:', error.message);
  }
}

exports.createEvent = async (req, res) => {
  try {
    const name = readText(req.body.name, 160);
    const description = readText(req.body.description, 5000);
    const place = readText(req.body.place, 240);
    const timeDate = readText(req.body.time_date, 160);
    const registrationMode = req.body.registration_mode ?? 'external';
    if (!name || !description || !place || !timeDate) {
      return res.status(400).json({ error: 'Name, description, place and time/date are required' });
    }
    if (!['external', 'internal'].includes(registrationMode)) {
      return res.status(400).json({ error: 'Registration mode must be external or internal' });
    }

    let registrationLink = null;
    if (registrationMode === 'external') {
      registrationLink = normalizeExternalUrl(req.body.registration_link);
      if (!registrationLink) {
        return res.status(400).json({ error: 'Enter a valid HTTP or HTTPS registration link' });
      }
    }

    const pictureUrl = req.file
      ? `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`
      : null;
    const { rows } = await db.query(
      `INSERT INTO events
        (name, description, place, time_date, registration_mode, registration_link, picture_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, name, description, place, time_date, registration_mode,
         registration_link, picture_url, created_at`,
      [name, description, place, timeDate, registrationMode, registrationLink, pictureUrl]
    );

    await invalidateAndWarmEvents({ updateHomeCounts: true });
    return res.status(201).json({ event: { ...rows[0], registration_count: 0, is_registered: false } });
  } catch (error) {
    console.error('Error creating event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteEvent = async (req, res) => {
  try {
    if (!isUuid(req.params.id)) return res.status(400).json({ error: 'Invalid event id' });
    const { rows } = await db.query(
      'DELETE FROM events WHERE id = $1 RETURNING id',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Event not found' });
    await invalidateAndWarmEvents({ updateHomeCounts: true });
    return res.json({ deleted: req.params.id });
  } catch (error) {
    console.error('Error deleting event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getEvents = async (req, res) => {
  try {
    res.setHeader('Cache-Control', 'private, no-store');
    const cachedCatalog = await cache.getOrLoadJson(EVENTS_CACHE_KEY, EVENTS_CACHE_TTL, queryEventCatalog);
    const events = Array.isArray(cachedCatalog?.events) ? cachedCatalog.events : [];

    const ids = events.map((event) => event.id).filter(isUuid);
    let registeredIds = new Set();
    if (req.user?.uid && ids.length) {
      const { rows } = await db.query(
        `SELECT r.event_id
         FROM event_registrations r
         INNER JOIN users u ON u.id = r.user_id
         WHERE u.firebase_uid = $1 AND r.event_id = ANY($2::uuid[])`,
        [req.user.uid, ids]
      );
      registeredIds = new Set(rows.map((row) => row.event_id));
    }

    return res.json({
      events: events.map((event) => ({
        ...event,
        registration_mode: event.registration_mode === 'internal' ? 'internal' : 'external',
        registration_link: event.registration_link ?? null,
        registration_count: Number(event.registration_count) || 0,
        is_registered: registeredIds.has(event.id),
      })),
    });
  } catch (error) {
    console.error('Error fetching events:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.registerForEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    if (!isUuid(eventId)) return res.status(400).json({ error: 'Invalid event id' });

    const event = await findInternalEvent(eventId);
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.registration_mode !== 'internal') {
      return res.status(409).json({ error: 'This event uses its external registration link' });
    }

    const userId = await findCurrentUserId(req.user.uid);
    if (!userId) return res.status(403).json({ error: 'CampusSetu student profile not found' });

    const { rows } = await db.query(
      `INSERT INTO event_registrations (event_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (event_id, user_id) DO NOTHING
       RETURNING registered_at`,
      [eventId, userId]
    );
    if (rows.length) {
      await invalidateAndWarmEvents();
      return res.status(201).json({ registered: true, already_registered: false, registered_at: rows[0].registered_at });
    }

    const existing = await db.query(
      'SELECT registered_at FROM event_registrations WHERE event_id = $1 AND user_id = $2',
      [eventId, userId]
    );
    return res.status(200).json({
      registered: true,
      already_registered: true,
      registered_at: existing.rows[0]?.registered_at ?? null,
    });
  } catch (error) {
    console.error('Error registering for event:', error);
    return res.status('23503' === error.code ? 404 : 500).json({
      error: error.code === '23503' ? 'Event or student profile no longer exists' : 'Internal server error',
    });
  }
};

exports.cancelEventRegistration = async (req, res) => {
  try {
    const eventId = req.params.id;
    if (!isUuid(eventId)) return res.status(400).json({ error: 'Invalid event id' });

    const event = await findInternalEvent(eventId);
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.registration_mode !== 'internal') {
      return res.status(409).json({ error: 'This event uses its external registration link' });
    }

    const userId = await findCurrentUserId(req.user.uid);
    if (!userId) return res.status(403).json({ error: 'CampusSetu student profile not found' });

    await db.query(
      'DELETE FROM event_registrations WHERE event_id = $1 AND user_id = $2',
      [eventId, userId]
    );
    await invalidateAndWarmEvents();
    return res.json({ registered: false });
  } catch (error) {
    console.error('Error cancelling event registration:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.getEventRegistrations = async (req, res) => {
  try {
    const eventId = req.params.id;
    if (!isUuid(eventId)) return res.status(400).json({ error: 'Invalid event id' });

    const event = await findInternalEvent(eventId);
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.registration_mode !== 'internal') {
      return res.status(409).json({ error: 'This event uses external registration' });
    }

    const { rows } = await db.query(
      `SELECT u.name, u.email, r.registered_at, COUNT(*) OVER()::int AS total
       FROM event_registrations r
       INNER JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1
       ORDER BY r.registered_at DESC
       LIMIT 500`,
      [eventId]
    );
    return res.json({
      registrations: rows.map(({ name, email, registered_at }) => ({ name, email, registered_at })),
      total: rows[0]?.total ?? 0,
      limit: 500,
    });
  } catch (error) {
    console.error('Error fetching event registrations:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
