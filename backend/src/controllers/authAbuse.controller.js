const { createHash } = require('crypto');
const db = require('../config/db');

function attemptKey(req, email) {
  const ip = String(req.ip || req.socket?.remoteAddress || 'unknown');
  return createHash('sha256')
    .update(ip + '\n' + String(email || '').trim().toLowerCase())
    .digest('hex');
}

// Four failed sign-ins in a rolling 10-minute window trigger a 2-minute cooldown.
exports.checkLogin = async (req, res) => {
  try {
    const key = attemptKey(req, req.body?.email);
    const { rows } = await db.query(
      'SELECT locked_until FROM auth_login_attempts WHERE attempt_key = $1',
      [key]
    );
    const until = rows[0]?.locked_until ? new Date(rows[0].locked_until) : null;
    const waitSeconds = until && until > new Date()
      ? Math.ceil((until.getTime() - Date.now()) / 1000)
      : 0;
    if (waitSeconds > 0) {
      return res.status(429).json({
        error: 'Too many sign-in attempts. Please wait before trying again.',
        wait_seconds: waitSeconds,
      });
    }
    return res.json({ allowed: true });
  } catch (error) {
    console.error('[auth-abuse] login check failed:', error.message);
    return res.status(503).json({ error: 'Sign-in protection is temporarily unavailable. Please retry shortly.' });
  }
};

exports.recordLoginFailure = async (req, res) => {
  try {
    const key = attemptKey(req, req.body?.email);
    const { rows } = await db.query(
      'INSERT INTO auth_login_attempts (attempt_key, failure_count, window_started_at) VALUES ($1, 1, NOW()) ' +
      'ON CONFLICT (attempt_key) DO UPDATE SET ' +
      'failure_count = CASE WHEN auth_login_attempts.locked_until > NOW() THEN auth_login_attempts.failure_count ' +
      'WHEN auth_login_attempts.window_started_at < NOW() - INTERVAL \'10 minutes\' THEN 1 ' +
      'ELSE LEAST(auth_login_attempts.failure_count + 1, 4) END, ' +
      'window_started_at = CASE WHEN auth_login_attempts.locked_until > NOW() THEN auth_login_attempts.window_started_at ' +
      'WHEN auth_login_attempts.window_started_at < NOW() - INTERVAL \'10 minutes\' THEN NOW() ' +
      'ELSE auth_login_attempts.window_started_at END, ' +
      'locked_until = CASE WHEN auth_login_attempts.locked_until > NOW() THEN auth_login_attempts.locked_until ' +
      'WHEN auth_login_attempts.window_started_at < NOW() - INTERVAL \'10 minutes\' THEN NULL ' +
      'WHEN auth_login_attempts.failure_count + 1 >= 4 THEN NOW() + INTERVAL \'2 minutes\' ELSE NULL END, ' +
      'updated_at = NOW() ' +
      'RETURNING failure_count, locked_until',
      [key]
    );
    const until = rows[0]?.locked_until ? new Date(rows[0].locked_until) : null;
    const waitSeconds = until && until > new Date()
      ? Math.ceil((until.getTime() - Date.now()) / 1000)
      : 0;
    return res.json({ failures: rows[0]?.failure_count ?? 0, wait_seconds: waitSeconds });
  } catch (error) {
    console.error('[auth-abuse] recording login failure failed:', error.message);
    return res.status(503).json({ error: 'Could not update sign-in protection. Please retry shortly.' });
  }
};

exports.clearLoginFailures = async (req, res) => {
  try {
    const email = String(req.user?.email || '').trim().toLowerCase();
    if (!email) return res.status(400).json({ error: 'Signed-in account has no email address.' });
    await db.query('DELETE FROM auth_login_attempts WHERE attempt_key = $1', [
      attemptKey(req, email),
    ]);
    return res.json({ cleared: true });
  } catch (error) {
    console.error('[auth-abuse] clearing login failures failed:', error.message);
    return res.status(503).json({ error: 'Could not update sign-in protection.' });
  }
};

exports.registerDeviceSignup = async (req, res) => {
  try {
    const deviceId = String(req.body?.device_id || '');
    if (!/^[a-z0-9._:-]{16,128}$/i.test(deviceId)) {
      return res.status(400).json({ error: 'A valid app installation identifier is required.' });
    }
    const deviceHash = createHash('sha256').update(deviceId).digest('hex');
    const { rows: existingDevice } = await db.query(
      'SELECT firebase_uid FROM auth_device_signups WHERE device_hash = $1',
      [deviceHash]
    );
    if (existingDevice.length && existingDevice[0].firebase_uid !== req.user.uid) {
      const { rows: existingAccount } = await db.query(
        'SELECT 1 FROM users WHERE firebase_uid = $1 LIMIT 1',
        [req.user.uid]
      );
      if (existingAccount.length) {
        return res.json({ registered: true, existing_account: true });
      }
      return res.status(409).json({
        error: 'This device has already been used to create an account. Sign in to an existing account instead.',
      });
    }
    const { rows } = await db.query(
      'INSERT INTO auth_device_signups (device_hash, firebase_uid) VALUES ($1, $2) ' +
      'ON CONFLICT (device_hash) DO UPDATE SET last_seen_at = NOW() ' +
      'WHERE auth_device_signups.firebase_uid = EXCLUDED.firebase_uid ' +
      'RETURNING firebase_uid',
      [deviceHash, req.user.uid]
    );
    if (!rows.length) {
      return res.status(409).json({
        error: 'This device has already been used to create an account. Sign in to an existing account instead.',
      });
    }
    return res.json({ registered: true });
  } catch (error) {
    console.error('[auth-abuse] signup device registration failed:', error.message);
    return res.status(503).json({ error: 'Could not verify this device for signup. Please retry shortly.' });
  }
};
