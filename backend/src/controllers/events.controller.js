const { randomBytes } = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const cache = require('../config/redis');
const { JWT_ORGANIZER_SECRET } = require('../middleware/auth');

const EVENTS_CACHE_KEY = 'events:all:v2';
const EVENTS_CACHE_TTL = 300;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^[0-9+\-\s()]{10,20}$/;

function isUuid(value) {
  return typeof value === 'string' && UUID_RE.test(value);
}

function generateEventCode() {
  const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code = 'EVT-';
  const bytes = randomBytes(6);
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
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
    'SELECT id, event_code, name, registration_mode FROM events WHERE id = $1 LIMIT 1',
    [eventId]
  );
  return rows[0] ?? null;
}

async function findEventByIdOrCode(idOrCode) {
  if (!idOrCode || typeof idOrCode !== 'string') return null;
  const trimmed = idOrCode.trim();
  const isId = isUuid(trimmed);
  const condition = isId ? 'e.id = $1' : 'UPPER(e.event_code) = UPPER($1)';

  const { rows } = await db.query(
    `SELECT e.id, e.event_code, e.name, e.description, e.place, e.time_date,
            COALESCE(e.registration_mode, 'external') AS registration_mode,
            e.registration_link, e.picture_url, e.created_at,
            COALESCE(e.organizer_access_enabled, false) AS organizer_access_enabled,
            e.organizer_id,
            COALESCE(r.registration_count, 0)::int AS registration_count
     FROM events e
     LEFT JOIN LATERAL (
       SELECT COUNT(*)::int AS registration_count
       FROM event_registrations er
       WHERE er.event_id = e.id
     ) r ON TRUE
     WHERE ${condition}
     LIMIT 1`,
    [trimmed]
  );
  return rows[0] ?? null;
}

async function queryEventCatalog() {
  const { rows } = await db.query(
    `SELECT e.id, e.event_code, e.name, e.description, e.place, e.time_date,
       COALESCE(e.registration_mode, 'external') AS registration_mode,
       e.registration_link, e.picture_url, e.created_at,
       COALESCE(e.organizer_access_enabled, false) AS organizer_access_enabled,
       e.organizer_id,
       COALESCE(r.registration_count, 0)::int AS registration_count
     FROM (
       SELECT id, event_code, name, description, place, time_date, registration_mode,
         registration_link, picture_url, created_at, organizer_access_enabled, organizer_id
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

    let eventCode = generateEventCode();
    for (let attempt = 0; attempt < 5; attempt++) {
      const check = await db.query('SELECT id FROM events WHERE event_code = $1', [eventCode]);
      if (!check.rows.length) break;
      eventCode = generateEventCode();
    }

    let organizerAccessEnabled = false;
    let organizerId = null;
    let organizerPasswordHash = null;

    if (registrationMode === 'internal') {
      organizerAccessEnabled = req.body.organizer_access_enabled === true || req.body.organizer_access_enabled === 'true';
      if (organizerAccessEnabled) {
        organizerId = readText(req.body.organizer_id, 100) || `org_${eventCode.toLowerCase().replace(/[^a-z0-9]/g, '')}`;
        const rawPassword = readText(req.body.organizer_password, 100);
        if (rawPassword && rawPassword.length >= 4) {
          organizerPasswordHash = await bcrypt.hash(rawPassword, 10);
        }
      }
    }

    const pictureUrl = req.file
      ? `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`
      : null;
    const { rows } = await db.query(
      `INSERT INTO events
        (name, description, place, time_date, registration_mode, registration_link, picture_url, event_code,
         organizer_access_enabled, organizer_id, organizer_password_hash)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING id, event_code, name, description, place, time_date, registration_mode,
         registration_link, picture_url, created_at, organizer_access_enabled, organizer_id`,
      [name, description, place, timeDate, registrationMode, registrationLink, pictureUrl, eventCode,
       organizerAccessEnabled, organizerId, organizerPasswordHash]
    );

    await invalidateAndWarmEvents({ updateHomeCounts: true });
    return res.status(201).json({ event: { ...rows[0], registration_count: 0, is_registered: false } });
  } catch (error) {
    console.error('Error creating event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.updateEvent = async (req, res) => {
  try {
    const eventId = req.params.id;
    if (!isUuid(eventId)) return res.status(400).json({ error: 'Invalid event id' });

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

    let pictureUpdate = '';
    const params = [name, description, place, timeDate, registrationMode, registrationLink, eventId];

    if (req.file) {
      const pictureUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      params.push(pictureUrl);
      pictureUpdate = `, picture_url = $${params.length}`;
    }

    let organizerUpdate = '';
    if (registrationMode === 'internal') {
      if (req.body.organizer_access_enabled !== undefined) {
        const enabled = req.body.organizer_access_enabled === true || req.body.organizer_access_enabled === 'true';
        params.push(enabled);
        organizerUpdate += `, organizer_access_enabled = $${params.length}`;
      }
      if (req.body.organizer_id !== undefined) {
        const orgId = readText(req.body.organizer_id, 100);
        params.push(orgId);
        organizerUpdate += `, organizer_id = $${params.length}`;
      }
      if (req.body.organizer_password) {
        const rawPassword = readText(req.body.organizer_password, 100);
        if (rawPassword && rawPassword.length >= 4) {
          const hash = await bcrypt.hash(rawPassword, 10);
          params.push(hash);
          organizerUpdate += `, organizer_password_hash = $${params.length}`;
        }
      }
    }

    const { rows } = await db.query(
      `UPDATE events
       SET name = $1,
           description = $2,
           place = $3,
           time_date = $4,
           registration_mode = $5,
           registration_link = $6
           ${pictureUpdate}
           ${organizerUpdate}
       WHERE id = $7
       RETURNING id, event_code, name, description, place, time_date, registration_mode,
         registration_link, picture_url, created_at, organizer_access_enabled, organizer_id`,
      params
    );

    if (!rows.length) return res.status(404).json({ error: 'Event not found' });

    const { rows: countRows } = await db.query(
      'SELECT COUNT(*)::int AS registration_count FROM event_registrations WHERE event_id = $1',
      [eventId]
    );

    await invalidateAndWarmEvents({ updateHomeCounts: true });
    return res.json({
      event: {
        ...rows[0],
        registration_count: countRows[0]?.registration_count ?? 0,
      },
    });
  } catch (error) {
    console.error('Error updating event:', error);
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

// ── GET /events/public/:idOrCode ────────────────────────────
// Publicly fetch event metadata by UUID or human-readable event_code (e.g. EVT-9X2L4M)
exports.getPublicEvent = async (req, res) => {
  try {
    const idOrCode = req.params.idOrCode;
    const event = await findEventByIdOrCode(idOrCode);
    if (!event) return res.status(404).json({ error: 'Event not found' });

    return res.json({
      event: {
        id: event.id,
        event_code: event.event_code,
        name: event.name,
        description: event.description,
        place: event.place,
        time_date: event.time_date,
        registration_mode: event.registration_mode === 'internal' ? 'internal' : 'external',
        registration_link: event.registration_link,
        picture_url: event.picture_url,
        registration_count: Number(event.registration_count) || 0,
        organizer_access_enabled: Boolean(event.organizer_access_enabled),
        created_at: event.created_at,
      },
    });
  } catch (error) {
    console.error('Error fetching public event:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// ── POST /events/organizer/login ────────────────────────────
// Dedicated event organizer login with Event Code / Organizer ID + Password.
// Issues scoped JWT valid for managing this event only.
exports.organizerLogin = async (req, res) => {
  try {
    const rawId = req.body.organizer_id || req.body.event_code || req.body.username;
    const rawPassword = req.body.password;

    const identifier = readText(rawId, 100);
    const password = readText(rawPassword, 100);

    if (!identifier || !password) {
      return res.status(400).json({ error: 'Event Code / Organizer ID and password are required' });
    }

    const { rows } = await db.query(
      `SELECT id, event_code, name, place, time_date, registration_mode, picture_url,
              organizer_access_enabled, organizer_id, organizer_password_hash
       FROM events
       WHERE (LOWER(organizer_id) = LOWER($1) OR UPPER(event_code) = UPPER($1))
         AND registration_mode = 'internal'
       LIMIT 1`,
      [identifier]
    );

    if (!rows.length) {
      return res.status(401).json({ error: 'Event not found or organizer access not configured' });
    }

    const event = rows[0];
    if (!event.organizer_access_enabled) {
      return res.status(403).json({ error: 'Organizer access is disabled for this event' });
    }

    if (!event.organizer_password_hash) {
      return res.status(401).json({ error: 'No organizer password has been set for this event. Please contact Admin.' });
    }

    const isMatch = await bcrypt.compare(password, event.organizer_password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect password for this event' });
    }

    const token = jwt.sign(
      {
        role: 'event_organizer',
        event_id: event.id,
        event_code: event.event_code,
        organizer_id: event.organizer_id,
        event_name: event.name,
      },
      JWT_ORGANIZER_SECRET,
      { expiresIn: '12h' }
    );

    const { rows: countRows } = await db.query(
      'SELECT COUNT(*)::int AS registration_count FROM event_registrations WHERE event_id = $1',
      [event.id]
    );

    return res.json({
      token,
      event: {
        id: event.id,
        event_code: event.event_code,
        name: event.name,
        place: event.place,
        time_date: event.time_date,
        registration_mode: event.registration_mode,
        picture_url: event.picture_url,
        registration_count: countRows[0]?.registration_count ?? 0,
        organizer_id: event.organizer_id,
      },
    });
  } catch (error) {
    console.error('Error during organizer login:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// ── POST /events/:idOrCode/public-register ───────────────────
// Direct guest registration without requiring app sign-up / login.
// Protected by IP rate limiting, input validation, and duplicate prevention.
exports.publicRegisterForEvent = async (req, res) => {
  try {
    const idOrCode = req.params.idOrCode;
    const event = await findEventByIdOrCode(idOrCode);
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.registration_mode !== 'internal') {
      return res.status(409).json({
        error: 'This event uses an external registration link',
        registration_link: event.registration_link,
      });
    }

    const name = readText(req.body.name, 100);
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const phone = readText(req.body.phone, 20);
    const college = readText(req.body.college, 150) || '';
    const branch = readText(req.body.branch, 100) || '';
    const notes = readText(req.body.notes, 300) || '';

    if (!name || name.length < 2) {
      return res.status(400).json({ error: 'Full name is required (min 2 characters)' });
    }
    if (!email || !EMAIL_RE.test(email) || email.length > 254) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }
    if (!phone || !PHONE_RE.test(phone)) {
      return res.status(400).json({ error: 'Enter a valid contact number (min 10 digits)' });
    }

    // Check if user is already registered for this event (guest email or registered student email)
    const { rows: existing } = await db.query(
      `SELECT r.id, r.registered_at
       FROM event_registrations r
       LEFT JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1
         AND (LOWER(r.custom_email) = $2 OR LOWER(u.email) = $2)
       LIMIT 1`,
      [event.id, email]
    );

    if (existing.length > 0) {
      return res.status(200).json({
        registered: true,
        already_registered: true,
        message: 'You are already registered for this event!',
        registered_at: existing[0].registered_at,
        event_name: event.name,
      });
    }

    const { rows } = await db.query(
      `INSERT INTO event_registrations
        (event_id, user_id, custom_name, custom_email, phone, custom_college, custom_branch, status, notes)
       VALUES ($1, NULL, $2, $3, $4, $5, $6, 'confirmed', $7)
       RETURNING id, registered_at`,
      [event.id, name, email, phone, college, branch, notes]
    );

    await invalidateAndWarmEvents();

    return res.status(201).json({
      registered: true,
      already_registered: false,
      registration_id: rows[0].id,
      registered_at: rows[0].registered_at,
      event_name: event.name,
      message: 'Registration successful! See you at the event.',
    });
  } catch (error) {
    console.error('Error in public registration:', error);
    if (error.code === '23505') {
      return res.status(200).json({
        registered: true,
        already_registered: true,
        message: 'You are already registered for this event!',
      });
    }
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
        event_code: event.event_code ?? null,
        registration_mode: event.registration_mode === 'internal' ? 'internal' : 'external',
        registration_link: event.registration_link ?? null,
        registration_count: Number(event.registration_count) || 0,
        organizer_access_enabled: Boolean(event.organizer_access_enabled),
        organizer_id: event.organizer_id ?? null,
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
      `SELECT
         r.id,
         r.event_id,
         r.user_id,
         COALESCE(r.custom_name, u.name, 'CampusSetu Attendee') AS name,
         COALESCE(r.custom_email, u.email, '') AS email,
         COALESCE(r.phone, '') AS phone,
         COALESCE(r.custom_college, u.college, '') AS college,
         COALESCE(r.custom_branch, u.branch, '') AS branch,
         COALESCE(u.course, '') AS course,
         COALESCE(u.campus_id, '') AS campus_id,
         COALESCE(r.status, 'confirmed') AS status,
         COALESCE(r.notes, '') AS notes,
         r.registered_at,
         (r.user_id IS NULL) AS is_guest,
         COUNT(*) OVER()::int AS total
       FROM event_registrations r
       LEFT JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1
       ORDER BY r.registered_at DESC
       LIMIT 2000`,
      [eventId]
    );

    return res.json({
      registrations: rows.map((row) => ({
        id: row.id,
        event_id: row.event_id,
        user_id: row.user_id,
        name: row.name,
        email: row.email,
        phone: row.phone,
        college: row.college,
        branch: row.branch,
        course: row.course,
        campus_id: row.campus_id || (row.is_guest ? 'Guest' : ''),
        status: row.status,
        notes: row.notes,
        registered_at: row.registered_at,
        is_guest: Boolean(row.is_guest),
      })),
      total: rows[0]?.total ?? 0,
      limit: 2000,
    });
  } catch (error) {
    console.error('Error fetching event registrations:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.updateEventRegistration = async (req, res) => {
  try {
    const { id: eventId, regId } = req.params;
    if (!isUuid(eventId) || !isUuid(regId)) {
      return res.status(400).json({ error: 'Invalid event or registration ID' });
    }

    const { name, email, phone, college, branch, status, notes } = req.body;
    const validStatuses = ['confirmed', 'attended', 'cancelled', 'waitlisted'];
    const finalStatus = status && validStatuses.includes(status.toLowerCase())
      ? status.toLowerCase()
      : 'confirmed';

    const { rows } = await db.query(
      `UPDATE event_registrations
       SET custom_name = CASE WHEN $1::text IS NOT NULL THEN $1::text ELSE custom_name END,
           custom_email = CASE WHEN $2::text IS NOT NULL THEN $2::text ELSE custom_email END,
           phone = CASE WHEN $3::text IS NOT NULL THEN $3::text ELSE phone END,
           custom_college = CASE WHEN $4::text IS NOT NULL THEN $4::text ELSE custom_college END,
           custom_branch = CASE WHEN $5::text IS NOT NULL THEN $5::text ELSE custom_branch END,
           status = $6,
           notes = CASE WHEN $7::text IS NOT NULL THEN $7::text ELSE notes END
       WHERE id = $8 AND event_id = $9
       RETURNING id`,
      [
        name !== undefined ? name.trim() : null,
        email !== undefined ? email.trim() : null,
        phone !== undefined ? phone.trim() : null,
        college !== undefined ? college.trim() : null,
        branch !== undefined ? branch.trim() : null,
        finalStatus,
        notes !== undefined ? notes.trim() : null,
        regId,
        eventId,
      ]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Registration not found' });
    }

    const { rows: fullRows } = await db.query(
      `SELECT
         r.id,
         r.event_id,
         r.user_id,
         COALESCE(r.custom_name, u.name, 'CampusSetu Attendee') AS name,
         COALESCE(r.custom_email, u.email, '') AS email,
         COALESCE(r.phone, '') AS phone,
         COALESCE(r.custom_college, u.college, '') AS college,
         COALESCE(r.custom_branch, u.branch, '') AS branch,
         COALESCE(u.course, '') AS course,
         COALESCE(u.campus_id, '') AS campus_id,
         COALESCE(r.status, 'confirmed') AS status,
         COALESCE(r.notes, '') AS notes,
         r.registered_at,
         (r.user_id IS NULL) AS is_guest
       FROM event_registrations r
       LEFT JOIN users u ON u.id = r.user_id
       WHERE r.id = $1 AND r.event_id = $2`,
      [regId, eventId]
    );

    return res.json({ registration: fullRows[0] || rows[0] });
  } catch (error) {
    console.error('Error updating event registration:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteEventRegistration = async (req, res) => {
  try {
    const { id: eventId, regId } = req.params;
    if (!isUuid(eventId) || !isUuid(regId)) {
      return res.status(400).json({ error: 'Invalid event or registration ID' });
    }

    const { rows } = await db.query(
      'DELETE FROM event_registrations WHERE id = $1 AND event_id = $2 RETURNING id',
      [regId, eventId]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Registration not found' });
    }

    await invalidateAndWarmEvents();
    return res.json({ deleted: true, id: regId });
  } catch (error) {
    console.error('Error deleting event registration:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.deleteAllEventRegistrations = async (req, res) => {
  try {
    const eventId = req.params.id;
    if (!isUuid(eventId)) {
      return res.status(400).json({ error: 'Invalid event ID' });
    }

    const { rowCount } = await db.query(
      'DELETE FROM event_registrations WHERE event_id = $1',
      [eventId]
    );

    await invalidateAndWarmEvents();
    return res.json({ deleted_all: true, count: rowCount });
  } catch (error) {
    console.error('Error deleting all event registrations:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

