const db = require('../config/db');

const REPORT_TARGETS = {
  post: 'posts',
  user: 'users',
  product: 'products',
  note: 'notes',
};

exports.createReport = async (req, res) => {
  try {
    const targetType = typeof req.body.target_type === 'string'
      ? req.body.target_type.trim()
      : '';
    const targetId = typeof req.body.target_id === 'string'
      ? req.body.target_id.trim()
      : '';
    const reason = typeof req.body.reason === 'string'
      ? req.body.reason.trim()
      : '';

    if (!Object.hasOwn(REPORT_TARGETS, targetType)) {
      return res.status(400).json({ error: 'Invalid report target type' });
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(targetId)) {
      return res.status(400).json({ error: 'A valid target_id is required' });
    }
    if (!reason || reason.length > 1000) {
      return res.status(400).json({ error: 'Reason is required and must be at most 1000 characters' });
    }

    const { rows: reporters } = await db.query(
      'SELECT id FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!reporters.length) return res.status(404).json({ error: 'User profile not found' });

    const table = REPORT_TARGETS[targetType];
    const { rows: targets } = await db.query(
      `SELECT id FROM ${table} WHERE id = $1${targetType === 'post' ? ' AND is_deleted = false' : ''}`,
      [targetId]
    );
    if (!targets.length) return res.status(404).json({ error: 'Report target not found' });
    if (targetType === 'user' && targets[0].id === reporters[0].id) {
      return res.status(400).json({ error: 'You cannot report your own account' });
    }

    const { rows } = await db.query(
      `INSERT INTO reports
         (reporter_id, target_type, target_id, reported_user_id, reason)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, reporter_id, target_type, target_id, reported_user_id, reason, status, created_at`,
      [
        reporters[0].id,
        targetType,
        targetId,
        targetType === 'user' ? targetId : null,
        reason,
      ]
    );
    return res.status(201).json(rows[0]);
  } catch (err) {
    console.error('[Reports] Create failed:', err.message);
    return res.status(500).json({ error: 'Unable to submit report' });
  }
};
