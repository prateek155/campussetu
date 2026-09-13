// backend/src/routes/tshare.routes.js
const router = require('express').Router();
const c = require('../controllers/tshare.controller');
const { requireAuth } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');

router.get('/my', requireAuth, c.getMyShares);
router.get('/:code', requireAuth, c.retrieveTshare);
router.post('/', requireAuth, validate(schemas.createTshare), c.createTshare);

module.exports = router;
