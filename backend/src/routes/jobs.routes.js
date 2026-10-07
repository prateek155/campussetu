// backend/src/routes/jobs.routes.js
const router = require('express').Router();
const c = require('../controllers/jobs.controller');
const { requireAuth } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');
const { cacheRoute, invalidateCache } = require('../middleware/cacheMiddleware');

router.get('/status', c.getJobsStatus);
router.get('/',    requireAuth, cacheRoute(90, (req) => `jobs:list:${JSON.stringify(req.query)}`), c.getJobs);
router.post('/',   requireAuth, validate(schemas.createJob), invalidateCache('jobs:*'), c.createJob);
router.get('/:id', requireAuth, cacheRoute(120, (req) => `jobs:single:${req.params.id}`), c.getJob);

module.exports = router;
