const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');
const reportsController = require('../controllers/reports.controller');

router.post('/', requireAuth, reportsController.createReport);

module.exports = router;
