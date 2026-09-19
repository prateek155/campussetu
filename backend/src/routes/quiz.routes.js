// backend/src/routes/quiz.routes.js
const router = require('express').Router();
const c = require('../controllers/quiz.controller');
const fc = require('../controllers/facultyAuth.controller');
const { requireAuth, requireFaculty } = require('../middleware/auth');

// ── Faculty Auth (no auth needed for register) ────────────────
router.post('/faculty/register', fc.registerFaculty);
router.post('/faculty/login-check', requireAuth, fc.loginCheck);

// ── Faculty Protected Routes ──────────────────────────────────
router.get('/faculty/profile', requireAuth, requireFaculty, c.getFacultyProfile);
router.get('/my', requireAuth, requireFaculty, c.getMyQuizzes);

// Image upload for questions
router.post('/upload/image', requireAuth, requireFaculty, c.uploadMiddleware, c.uploadQuestionImage);

// Quiz CRUD (faculty)
router.post('/', requireAuth, requireFaculty, c.createQuiz);
router.get('/faculty/:id', requireAuth, requireFaculty, c.getQuizDetail);
router.post('/:id/start', requireAuth, requireFaculty, c.startQuiz);
router.post('/:id/end', requireAuth, requireFaculty, c.endQuiz);
router.get('/:id/results', requireAuth, requireFaculty, c.getResults);

// ── Student Protected Routes ──────────────────────────────────
router.get('/live', requireAuth, c.getLiveQuizzes);
router.post('/join', requireAuth, c.joinQuiz);
router.post('/answer', requireAuth, c.submitAnswer);
router.get('/:id/my-result', requireAuth, c.getMyResult);

module.exports = router;
