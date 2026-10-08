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

// ── Ambassador applications (admin view) ──────────────────────
router.get('/ambassador/applications', async (req, res) => {
  try {
    const snapshot = await firebaseAdmin.firestore()
      .collection('campus_ambassadors')
      .get();
    const applications = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        created_at: data.created_at?.toDate ? data.created_at.toDate().toISOString() : data.created_at,
        updated_at: data.updated_at?.toDate ? data.updated_at.toDate().toISOString() : data.updated_at,
      };
    });
    // Sort newest first
    applications.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
    return res.json({ applications });
  } catch (error) {
    console.error('[admin] fetch ambassador applications failed:', error.message);
    return res.status(500).json({ error: 'Could not fetch ambassador applications.' });
  }
});

router.put('/ambassador/applications/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status, review_note } = req.body;
  if (!status) return res.status(400).json({ error: 'Status is required' });
  try {
    const updateData = {
      status,
      updated_at: firebaseAdmin.firestore.FieldValue.serverTimestamp(),
    };
    if (review_note !== undefined) {
      updateData.review_note = review_note;
    }
    await firebaseAdmin.firestore()
      .collection('campus_ambassadors')
      .doc(id)
      .set(updateData, { merge: true });
    return res.json({ success: true, id, status });
  } catch (error) {
    console.error('[admin] update ambassador status failed:', error.message);
    return res.status(500).json({ error: 'Could not update ambassador status.' });
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
