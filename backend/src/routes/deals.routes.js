// backend/src/routes/deals.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const dealsController = require('../controllers/deals.controller');

const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `deal-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (/^image\/(jpeg|jpg|png|webp)$/.test(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG/PNG/WEBP images allowed (max 2 MB)'));
    }
  },
  limits: { fileSize: 2 * 1024 * 1024 },
});

router.use(requireAuth);

// The controller caches only the public deal catalog, avoiding duplicate
// response caches with conflicting invalidation rules.
router.get('/', dealsController.getDeals);
router.get('/admin/all', requireAdmin, dealsController.getAdminDeals);
router.get('/:id/redemptions', requireAdmin, dealsController.getDealRedemptions);

// Admin mutations update PostgreSQL first, then refresh the catalog cache.
router.post('/', requireAdmin, upload.single('image'), dealsController.createDeal);
router.put('/:id', requireAdmin, upload.single('image'), dealsController.updateDeal);
router.post('/:id/restore', requireAdmin, dealsController.restoreDeal);
router.delete('/:id', requireAdmin, dealsController.deleteDeal);

module.exports = router;
