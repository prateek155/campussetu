// backend/src/routes/admin.routes.js
const router = require('express').Router();
const c = require('../controllers/admin.controller');
const jobsCtrl = require('../controllers/jobs.controller');
const { requireAuth, requireAdmin, requireEnterprise } = require('../middleware/auth');
const firebaseAdmin = require('../config/firebase');

// Allow enterprise app to redeem deals
router.post('/enterprise/redeem', requireAuth, requireEnterprise, c.redeemDeal);

// All admin routes require auth + admin claim
router.use(requireAuth, requireAdmin);

router.put('/ambassador/program', async (req, res) => {
  const isOpen = req.body?.is_open;
  if (typeof isOpen !== 'boolean') return res.status(400).json({ error: 'is_open must be a boolean' });
  try {
    await firebaseAdmin.firestore()
      .collection('app_config').doc('ambassador_program')
      .set({
        is_open: isOpen,
        isOpen,
        updated_at: firebaseAdmin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    return res.json({ is_open: isOpen });
  } catch (error) {
    console.error('[admin] ambassador program update failed:', error.message);
    return res.status(500).json({ error: 'Could not update ambassador program status.' });
  }
});

router.get('/stats', c.getStats);
router.get('/reports', c.getReports);
router.post('/reports/:id/resolve', c.resolveReport);
router.get('/jobs/pending', c.getPendingJobs);
router.put('/jobs/:id/approve', c.approveJob);
router.put('/notes/:id/approve', c.approveNote);
router.post('/broadcast', c.broadcast);
router.post('/points', c.grantPoints);
router.get('/points/transfers', c.getPointsTransfers);
router.get('/jobs/status', jobsCtrl.getJobsStatus);
router.put('/jobs/status', jobsCtrl.setJobsStatus);

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
