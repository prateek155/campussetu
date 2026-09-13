// backend/src/routes/travel.routes.js
const express = require('express');
const router = express.Router();
const travelController = require('../controllers/travel.controller');
const { requireAuth } = require('../middleware/auth');

router.get('/', travelController.getRides);
router.post('/', requireAuth, travelController.createRide);

module.exports = router;
