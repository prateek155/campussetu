// backend/src/routes/deals.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const dealsController = require('../controllers/deals.controller');
const { cacheRoute, invalidateCache } = require('../middleware/cacheMiddleware');

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

// GET deals — cached 3 minutes (deals rarely change)
router.get('/', cacheRoute(180, () => 'deals:list'), dealsController.getDeals);

// Admin mutations — invalidate cache
router.post('/', requireAdmin, upload.single('image'), invalidateCache('deals:*'), dealsController.createDeal);
router.delete('/:id', requireAdmin, invalidateCache('deals:*'), dealsController.deleteDeal);

module.exports = router;
