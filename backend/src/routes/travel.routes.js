// backend/src/routes/travel.routes.js
const express = require('express');
const router = express.Router();
const travelController = require('../controllers/travel.controller');
const { requireAuth } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');
const { cacheRoute, invalidateCache } = require('../middleware/cacheMiddleware');

// GET rides — cached 60 seconds (active rides change frequently)
router.get('/',  requireAuth, cacheRoute(60, () => 'travel:list'), travelController.getRides);
// POST new ride — invalidate ride list
router.post('/', requireAuth, validate(schemas.createRide), invalidateCache('travel:*'), travelController.createRide);

module.exports = router;
