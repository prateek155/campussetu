const router = require('express').Router();
const controller = require('../controllers/resume.controller');
const { requireAuth } = require('../middleware/auth');

router.use((req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, private');
  next();
});

// Mobile-to-browser auth handoff: exchange is one-time and expires quickly.
router.post('/handoff/exchange', controller.exchangeHandoff);
router.post('/handoff', requireAuth, controller.createHandoff);

router.get('/', requireAuth, controller.list);
router.post('/', requireAuth, controller.create);
router.get('/:id', requireAuth, controller.get);
router.put('/:id', requireAuth, controller.update);
router.delete('/:id', requireAuth, controller.remove);

module.exports = router;
