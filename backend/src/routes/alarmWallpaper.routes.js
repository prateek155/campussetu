// backend/src/routes/alarmWallpaper.routes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { randomUUID } = require('crypto');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const c = require('../controllers/alarmWallpaper.controller');

// Multer — accept images, riv, mp4
const ALLOWED_MIME = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'video/mp4': '.mp4',
};

const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const finalExt = ext === '.riv' ? '.riv' : (ALLOWED_MIME[file.mimetype] || '.jpg');
    cb(null, `wallpaper-${randomUUID()}${finalExt}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const isImageOrVideo = ALLOWED_MIME[file.mimetype];
    const isRive = ext === '.riv' && (file.mimetype === 'application/octet-stream' || file.mimetype === 'application/x-rive' || file.mimetype === 'application/rive');
    if (isImageOrVideo || isRive) {
      cb(null, true);
    } else {
      cb(new Error(`File type not allowed. Allowed: jpg, png, webp, .riv, mp4`));
    }
  },
  limits: {
    fileSize: 50 * 1024 * 1024, // 50 MB max (videos can be large)
  },
});

// ── Routes ────────────────────────────────────────────────────────────────────

// GET — any authenticated user (user app fetches wallpapers)
router.get('/', requireAuth, c.list);

// Admin only mutations
router.post('/',           requireAuth, requireAdmin, upload.single('file'), c.create);
router.delete('/:id',      requireAuth, requireAdmin, c.remove);
router.patch('/:id/order', requireAuth, requireAdmin, c.reorder);

module.exports = router;
