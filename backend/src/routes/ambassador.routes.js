const router = require('express').Router();
const admin = require('../config/firebase');

const configRef = () => admin.firestore().collection('app_config').doc('ambassador_program');

router.get('/program/status', async (req, res, next) => {
  try {
    const snapshot = await configRef().get();
    const data = snapshot.exists ? snapshot.data() : null;
    return res.json({ is_open: data?.is_open ?? data?.isOpen ?? true });
  } catch (error) {
    console.error('[ambassador] status read failed:', error.message);
    return res.status(503).json({ error: 'Program status is temporarily unavailable.' });
  }
});

router.get('/application/me', require('../middleware/auth').requireAuth, async (req, res) => {
  try {
    const snapshot = await admin.firestore().collection('campus_ambassadors').doc(req.user.uid).get();
    return res.json(snapshot.exists ? { application: { id: snapshot.id, ...snapshot.data() } } : { application: null });
  } catch (error) {
    console.error('[ambassador] application read failed:', error.message);
    return res.status(503).json({ error: 'Application status is temporarily unavailable.' });
  }
});

router.post('/application', require('../middleware/auth').requireAuth, async (req, res) => {
  const fields = ['name', 'age', 'phone', 'degree', 'current_year', 'college_name', 'previous_experience'];
  const values = Object.fromEntries(fields.map((field) => [field, String(req.body?.[field] ?? '').trim()]));
  if (fields.some((field) => !values[field]) || values.name.length > 120 || values.phone.length > 30 ||
      values.previous_experience.length > 2000) {
    return res.status(400).json({ error: 'Please complete all required application fields.' });
  }
  const firestore = admin.firestore();
  const programRef = configRef();
  const applicationRef = firestore.collection('campus_ambassadors').doc(req.user.uid);
  try {
    const result = await firestore.runTransaction(async (transaction) => {
      const program = await transaction.get(programRef);
      const config = program.exists ? program.data() : null;
      const isOpen = config?.is_open ?? config?.isOpen ?? true;
      if (!isOpen) return false;
      const existing = await transaction.get(applicationRef);
      const now = admin.firestore.FieldValue.serverTimestamp();
      transaction.set(applicationRef, {
        ...values,
        user_id: req.user.uid,
        status: existing.exists ? (existing.data().status || 'pending') : 'pending',
        created_at: existing.exists ? existing.data().created_at : now,
        updated_at: now,
      }, { merge: true });
      return true;
    });
    if (!result) return res.status(409).json({ error: 'This program is now inactive.' });
    return res.json({ submitted: true });
  } catch (error) {
    console.error('[ambassador] application submission failed:', error.message);
    return res.status(503).json({ error: 'Could not submit the application. Please retry.' });
  }
});

module.exports = router;
