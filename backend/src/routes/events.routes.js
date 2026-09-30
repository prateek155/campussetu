// backend/src/routes/events.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const { randomUUID } = require('crypto');
const { requireAuth, requireAdmin, requireStudent } = require('../middleware/auth');
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

router.use(requireAuth);

// The controller caches the shared catalog, then adds each user's registration
// state separately so one student's response can never be served to another.
router.get('/', eventsController.getEvents);

router.post('/:id/register', requireStudent, eventsController.registerForEvent);
router.delete('/:id/register', requireStudent, eventsController.cancelEventRegistration);
router.get('/:id/registrations', requireAdmin, eventsController.getEventRegistrations);

// Admin mutations — invalidate cache on change
router.post('/', requireAdmin, upload.single('image'), eventsController.createEvent);
router.delete('/:id', requireAdmin, eventsController.deleteEvent);

module.exports = router;
