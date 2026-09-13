// backend/src/routes/events.routes.js
const express = require('express');
const router = express.Router();
const { requireAuth, requireAdmin } = require('../middleware/auth');
const eventsController = require('../controllers/events.controller');

// All endpoints require authentication
router.use(requireAuth);

// GET events (all authenticated users)
router.get('/', eventsController.getEvents);

// POST events (only admins)
router.post('/', requireAdmin, eventsController.createEvent);

// DELETE events (only admins)
router.delete('/:id', requireAdmin, eventsController.deleteEvent);

module.exports = router;
