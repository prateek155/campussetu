// backend/src/routes/deals.routes.js
const express = require('express');
const router = express.Router();
const { requireAuth, requireAdmin } = require('../middleware/auth');
const dealsController = require('../controllers/deals.controller');

// All endpoints require authentication
router.use(requireAuth);

// GET deals (all authenticated users)
router.get('/', dealsController.getDeals);

// POST deals (only admins)
router.post('/', requireAdmin, dealsController.createDeal);

// DELETE deals (only admins)
router.delete('/:id', requireAdmin, dealsController.deleteDeal);

module.exports = router;
