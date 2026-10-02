// backend/src/routes/enterprise.routes.js
const router = require('express').Router();
const ec = require('../controllers/enterprise.controller');
const { requireAuth } = require('../middleware/auth');

// All enterprise POS routes require valid authentication
router.use(requireAuth);

// Store Profile & Settings
router.get('/profile', ec.getProfile);
router.post('/profile', ec.saveProfile);

// Food Items & Menu
router.get('/food-items', ec.getFoodItems);
router.post('/food-items', ec.addFoodItem);
router.post('/food-items/bulk', ec.bulkImportFoodItems);
router.put('/food-items/:id', ec.updateFoodItem);
router.delete('/food-items/:id', ec.deleteFoodItem);

// Bills & Sales
router.get('/bills', ec.getBills);
router.post('/bills', ec.createBill);

// Inventory
router.get('/inventory', ec.getInventory);
router.post('/inventory', ec.addInventory);
router.delete('/inventory/:id', ec.deleteInventory);

// CRM / Udhaar
router.get('/udhaar', ec.getUdhaar);
router.post('/udhaar', ec.addUdhaar);

// Staff & Advances
router.get('/staff', ec.getStaff);
router.post('/staff', ec.addStaff);
router.delete('/staff/:id', ec.deleteStaff);
router.post('/staff/advance', ec.addStaffAdvance);

// CampusSetu Deal Redemption
router.post('/redeem', ec.redeemDeal);

// Offline-first Delta Sync
router.post('/sync', ec.syncDelta);

module.exports = router;
