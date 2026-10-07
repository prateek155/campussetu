// backend/src/routes/events.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { randomUUID } = require('crypto');
const { requireAuth, optionalAuth, requireAdmin, requireStudent, requireOrganizerOrAdmin } = require('../middleware/auth');
const eventsController = require('../controllers/events.controller');

const imageExtensions = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => cb(null, `event-${randomUUID()}${imageExtensions[file.mimetype] || '.jpg'}`),
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (imageExtensions[file.mimetype]) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG/PNG/WEBP images allowed (max 2 MB)'));
    }
  },
  limits: { fileSize: 2 * 1024 * 1024 },
});

const publicRegistrationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many registration requests. Please wait a few minutes and try again.' },
});

const publicEventLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
});

const organizerLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many organizer login attempts. Please wait 15 minutes and try again.' },
});

// ── Public Routes (no login required) ────────────────────────
router.get('/public/:idOrCode', publicEventLimiter, eventsController.getPublicEvent);
router.post('/:idOrCode/public-register', publicRegistrationLimiter, eventsController.publicRegisterForEvent);

// ── Event Organizer Login ────────────────────────────────────
router.post('/organizer/login', organizerLoginLimiter, eventsController.organizerLogin);

// ── Event Catalog (public or authenticated) ──────────────────
router.get('/', optionalAuth, eventsController.getEvents);

// ── Student Protected Routes ──────────────────────────────────
router.post('/:id/register', requireAuth, requireStudent, eventsController.registerForEvent);
router.delete('/:id/register', requireAuth, requireStudent, eventsController.cancelEventRegistration);

// ── Event Attendee Management (Admin or Event Organizer) ──────
// Organizers can view, edit attendee info, and delete individual attendee
router.get('/:id/registrations', requireOrganizerOrAdmin, eventsController.getEventRegistrations);
router.put('/:id/registrations/:regId', requireOrganizerOrAdmin, eventsController.updateEventRegistration);
router.delete('/:id/registrations/:regId', requireOrganizerOrAdmin, eventsController.deleteEventRegistration);

// ── Super Admin Only (Organizers Strictly Blocked) ────────────
// Wipe all registrations or mutating/deleting events requires Super Admin
router.delete('/:id/registrations', requireAuth, requireAdmin, eventsController.deleteAllEventRegistrations);
router.post('/', requireAuth, requireAdmin, upload.single('image'), eventsController.createEvent);
router.put('/:id', requireAuth, requireAdmin, upload.single('image'), eventsController.updateEvent);
router.delete('/:id', requireAuth, requireAdmin, eventsController.deleteEvent);

module.exports = router;
