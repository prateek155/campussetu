// backend/src/routes/notes.routes.js
const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const c = require('../controllers/notes.controller');
const { requireAuth } = require('../middleware/auth');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, process.env.UPLOAD_DIR || './uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') cb(null, true);
    else cb(new Error('Only PDF files are allowed'));
  },
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB || '10')) * 1024 * 1024 },
});

router.get('/', requireAuth, c.getNotes);
router.post('/', requireAuth, upload.single('file'), c.uploadNote);
router.post('/:id/download', requireAuth, c.incrementDownload);

module.exports = router;
