// backend/src/routes/events.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const eventsController = require('../controllers/events.controller');

const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `event-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (/^image\/(jpeg|jpg|png|webp)$/.test(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG/PNG/WEBP images allowed (max 2 MB)'));
    }
  },
  limits: { fileSize: 2 * 1024 * 1024 },
});

// All endpoints require authentication
router.use(requireAuth);

// GET events (all authenticated users)
router.get('/', eventsController.getEvents);

// POST events (only admins)
router.post('/', requireAdmin, upload.single('image'), eventsController.createEvent);

// DELETE events (only admins)
router.delete('/:id', requireAdmin, eventsController.deleteEvent);

module.exports = router;
