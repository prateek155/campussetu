// src/routes/flatmates.routes.js
const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const c = require('../controllers/flatmates.controller');
const { requireAuth } = require('../middleware/auth');

const storage = multer.diskStorage({
  destination: (req, file, cb) =>
    cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `flatmate-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
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

router.get('/', requireAuth, c.getFlatmates);
router.post('/', requireAuth, upload.array('photos', 2), c.createFlatmate);
router.delete('/:id', requireAuth, c.deleteFlatmate);

module.exports = router;
