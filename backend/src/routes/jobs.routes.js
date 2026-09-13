// backend/src/routes/jobs.routes.js
const router = require('express').Router();
const c = require('../controllers/jobs.controller');
const { requireAuth } = require('../middleware/auth');

router.get('/', requireAuth, c.getJobs);
router.post('/', requireAuth, c.createJob);
router.get('/:id', requireAuth, c.getJob);

module.exports = router;
