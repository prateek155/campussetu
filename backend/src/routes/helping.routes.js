// backend/src/routes/helping.routes.js
const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const c = require('../controllers/helping.controller');
const { requireAuth } = require('../middleware/auth');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `helping-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (/^image\/(jpeg|png|webp|jpg)$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only JPG/PNG/WEBP images allowed (max 2MB)'));
  },
  limits: { fileSize: 2 * 1024 * 1024 },
});

router.get('/', requireAuth, c.getTasks);
router.post('/', requireAuth, upload.single('image'), c.createTask);
router.get('/:id', requireAuth, c.getTask);
router.post('/:id/apply', requireAuth, c.applyTask);
router.post('/:id/accept', requireAuth, c.acceptApplication);
router.post('/:id/complete', requireAuth, c.completeTask);
router.delete('/:id', requireAuth, c.deleteTask);

module.exports = router;
