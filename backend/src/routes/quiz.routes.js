// backend/src/routes/quiz.routes.js
const router = require('express').Router();
const c = require('../controllers/quiz.controller');
const fc = require('../controllers/facultyAuth.controller');
const { requireAuth, requireFaculty, requireStudent } = require('../middleware/auth');

// ── Faculty Auth (no auth needed for register) ────────────────
router.post('/faculty/register', fc.registerFaculty);
router.post('/faculty/login-check', requireAuth, fc.loginCheck);

// ── Faculty Protected Routes ──────────────────────────────────
router.get('/faculty/profile', requireAuth, requireFaculty, c.getFacultyProfile);
router.get('/my', requireAuth, requireFaculty, c.getMyQuizzes);
router.get('/analytics', requireAuth, requireFaculty, c.getFacultyAnalytics);
router.get('/question-bank', requireAuth, requireFaculty, c.getQuestionBank);

// Image upload for questions
router.post('/upload/image', requireAuth, requireFaculty, c.uploadMiddleware, c.uploadQuestionImage);

// Quiz CRUD (faculty)
router.post('/', requireAuth, requireFaculty, c.createQuiz);
router.put('/:id', requireAuth, requireFaculty, c.updatePaperTest);
router.get('/faculty/:id', requireAuth, requireFaculty, c.getQuizDetail);
router.post('/:id/start', requireAuth, requireFaculty, c.startQuiz);
router.post('/:id/end', requireAuth, requireFaculty, c.endQuiz);
router.get('/:id/results', requireAuth, requireFaculty, c.getResults);
router.post('/:id/publish', requireAuth, requireFaculty, c.publishPaperTest);

// ── Student Protected Routes ──────────────────────────────────
router.get('/live', requireAuth, requireStudent, c.getLiveQuizzes);
router.get('/tests', requireAuth, requireStudent, c.getPaperTests);
router.get('/:id/paper', requireAuth, requireStudent, c.getPaperTest);
router.patch('/:id/answer', requireAuth, requireStudent, c.savePaperTestAnswer);
router.post('/:id/submit', requireAuth, requireStudent, c.submitPaperTest);
router.post('/:id/flag', requireAuth, requireStudent, c.recordPaperTestFlag);
router.post('/join', requireAuth, requireStudent, c.joinQuiz);
router.post('/answer', requireAuth, requireStudent, c.submitAnswer);
router.get('/:id/my-result', requireAuth, requireStudent, c.getMyResult);

module.exports = router;
