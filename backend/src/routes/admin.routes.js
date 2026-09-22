// backend/src/routes/admin.routes.js
const router = require('express').Router();
const c = require('../controllers/admin.controller');
const { requireAuth, requireAdmin, requireEnterprise } = require('../middleware/auth');

// Allow enterprise app to redeem deals
router.post('/enterprise/redeem', requireAuth, requireEnterprise, c.redeemDeal);

// All admin routes require auth + admin claim
router.use(requireAuth, requireAdmin);

router.get('/stats', c.getStats);
router.get('/reports', c.getReports);
router.post('/reports/:id/resolve', c.resolveReport);
router.get('/jobs/pending', c.getPendingJobs);
router.put('/jobs/:id/approve', c.approveJob);
router.put('/notes/:id/approve', c.approveNote);
router.post('/broadcast', c.broadcast);
router.post('/points', c.grantPoints);

// ── User management ────────────────────────────────────────
router.get('/users/meta', c.getUsersMeta);
router.get('/users', c.getUsers);
router.put('/users/:id/block', c.blockUser);
router.put('/users/:id/unblock', c.unblockUser);
router.post('/users/:id/freeze', c.freezeUser);
router.post('/users/:id/restrict', c.restrictUser);

// ── Pulse / Activity monitoring ───────────────────────────
router.get('/pulse/stats', c.getPulseStats);
router.get('/pulse/live-feed', c.getLiveFeed);
router.get('/pulse/suspicious', c.getSuspiciousActivities);
router.post('/pulse/suspicious/:userId/dismiss', c.dismissSuspicious);

// ── Flatmates (admin view) ────────────────────────────────
const flatmatesCtrl = require('../controllers/flatmates.controller');
router.get('/flatmates', flatmatesCtrl.adminGetFlatmates);
router.delete('/flatmates/:id', flatmatesCtrl.deleteFlatmate);

module.exports = router;
