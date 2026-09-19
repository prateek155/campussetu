// backend/src/routes/posts.routes.js
const router = require('express').Router();
const c = require('../controllers/posts.controller');
const { requireAuth } = require('../middleware/auth');

router.get('/feed', requireAuth, c.getFeed);
router.post('/', requireAuth, c.createPost);
router.delete('/:id', requireAuth, c.deletePost);
router.post('/:id/like', requireAuth, c.toggleLike);
router.get('/:id/comments', requireAuth, c.getComments);
router.post('/:id/comment', requireAuth, c.addComment);

module.exports = router;
