// backend/src/routes/products.routes.js
const router = require('express').Router();
const c = require('../controllers/products.controller');
const { requireAuth } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validate');

router.get('/', requireAuth, c.getProducts);
router.post('/', requireAuth, validate(schemas.createProduct), c.createProduct);
router.get('/:id', requireAuth, c.getProduct);
router.patch('/:id/status', requireAuth, c.updateProductStatus);

module.exports = router;
