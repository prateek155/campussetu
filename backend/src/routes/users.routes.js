// backend/src/routes/users.routes.js
const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const c = require('../controllers/users.controller');
const { requireAuth } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');

const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `profile-${req.user.uid}-${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (/^image\/(jpeg|png|webp|jpg)$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Only JPG/PNG/WEBP images allowed'));
  },
});

router.get('/me', requireAuth, c.getMe);
router.get('/discover', requireAuth, c.discoverStudents);
router.get('/by-campus/:campusId', requireAuth, c.getByCampusId);
router.post('/transfer', requireAuth, c.transferPoints);
router.post('/:id/photo', requireAuth, upload.single('photo'), c.uploadPhoto);
router.get('/:id', requireAuth, c.getUser);
router.put('/:id/profile', requireAuth, validate(schemas.updateProfile), c.updateProfile);

module.exports = router;
