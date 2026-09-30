const { createHash, randomBytes, randomInt } = require('crypto');
const bcrypt = require('bcryptjs');
const db = require('../config/db');
const firebaseAdmin = require('../config/firebase');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_TTL_MINUTES = 10;
const RESET_TOKEN_TTL_MINUTES = 10;
const GENERIC_REQUEST_MESSAGE = 'If an account exists for that email, a verification code has been sent.';

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function createOtp() {
  return Array.from({ length: 4 }, () => randomInt(1, 10)).join('');
}

function tokenHash(token) {
  return createHash('sha256').update(token).digest('hex');
}

async function sendOtpEmail(email, otp) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.PASSWORD_RESET_FROM_EMAIL;
  if (!apiKey || !from) throw new Error('Password reset email is not configured');

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: 'Your CampusSetu password reset code',
      text: `Your CampusSetu verification code is ${otp}. It expires in ${OTP_TTL_MINUTES} minutes. If you did not request this, ignore this email.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#17212b"><h2>Reset your CampusSetu password</h2><p>Use this verification code to continue:</p><p style="font-size:32px;font-weight:700;letter-spacing:10px;padding:14px 18px;background:#f2f7f8;border-radius:12px;display:inline-block">${otp}</p><p>This code expires in ${OTP_TTL_MINUTES} minutes. If you did not request a password reset, you can ignore this email.</p></div>`,
    }),
    signal: AbortSignal.timeout(12000),
  });

  if (!response.ok) {
    // Do not log the email, OTP, API key, or provider response body.
    console.error(`[PasswordReset] Email provider rejected request (HTTP ${response.status})`);
    throw new Error('Password reset email delivery failed');
  }
}

exports.requestOtp = async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  if (!EMAIL_RE.test(email) || email.length > 254) {
    return res.status(400).json({ error: 'Enter a valid email address.' });
  }

  if (!process.env.RESEND_API_KEY || !process.env.PASSWORD_RESET_FROM_EMAIL) {
    return res.status(503).json({ error: 'Password reset email is temporarily unavailable.' });
  }

  try {
    const { rows: accounts } = await db.query(
      `SELECT firebase_uid, email FROM users
       WHERE LOWER(email) = $1 AND is_banned = false LIMIT 1`,
      [email],
    );
    if (!accounts.length) return res.status(202).json({ message: GENERIC_REQUEST_MESSAGE });

    const account = accounts[0];
    const firebaseUser = await firebaseAdmin.auth().getUser(account.firebase_uid);
    if (!firebaseUser.providerData.some((provider) => provider.providerId === 'password')) {
      return res.status(202).json({ message: GENERIC_REQUEST_MESSAGE });
    }
    const otp = createOtp();
    const otpHash = await bcrypt.hash(otp, 10);
    const { rows: reserved } = await db.query(
      `INSERT INTO password_reset_otps
         (firebase_uid, otp_hash, reset_token_hash, expires_at, attempts,
          sent_at, window_started_at, requests_in_window)
       VALUES ($1, $2, NULL, NOW() + INTERVAL '${OTP_TTL_MINUTES} minutes', 0,
               NOW(), NOW(), 1)
       ON CONFLICT (firebase_uid) DO UPDATE SET
         otp_hash = EXCLUDED.otp_hash,
         reset_token_hash = NULL,
         expires_at = EXCLUDED.expires_at,
         attempts = 0,
         requests_in_window = CASE
           WHEN password_reset_otps.window_started_at <= NOW() - INTERVAL '15 minutes' THEN 1
           ELSE password_reset_otps.requests_in_window + 1
         END,
         window_started_at = CASE
           WHEN password_reset_otps.window_started_at <= NOW() - INTERVAL '15 minutes' THEN NOW()
           ELSE password_reset_otps.window_started_at
         END,
         sent_at = NOW()
       WHERE password_reset_otps.sent_at <= NOW() - INTERVAL '60 seconds'
         AND (password_reset_otps.window_started_at <= NOW() - INTERVAL '15 minutes'
              OR password_reset_otps.requests_in_window < 3)
       RETURNING firebase_uid`,
      [account.firebase_uid, otpHash],
    );
    if (!reserved.length) return res.status(202).json({ message: GENERIC_REQUEST_MESSAGE });

    try {
      await sendOtpEmail(account.email, otp);
    } catch (error) {
      await db.query(
        'DELETE FROM password_reset_otps WHERE firebase_uid = $1 AND otp_hash = $2',
        [account.firebase_uid, otpHash],
      ).catch(() => {});
      console.error('[PasswordReset] Could not send verification email');
      // Keep the response indistinguishable from an unknown account.
      return res.status(202).json({ message: GENERIC_REQUEST_MESSAGE });
    }

    return res.status(202).json({ message: GENERIC_REQUEST_MESSAGE });
  } catch (error) {
    console.error('[PasswordReset] Request failed:', error.message);
    return res.status(500).json({ error: 'Could not start password reset.' });
  }
};

exports.verifyOtp = async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const otp = typeof req.body?.otp === 'string' ? req.body.otp : '';
  if (!EMAIL_RE.test(email) || !/^[1-9]{4}$/.test(otp)) {
    return res.status(400).json({ error: 'The code is invalid or expired.' });
  }

  let client;
  try {
    const { rows: accounts } = await db.query(
      'SELECT firebase_uid FROM users WHERE LOWER(email) = $1 AND is_banned = false LIMIT 1',
      [email],
    );
    if (!accounts.length) return res.status(400).json({ error: 'The code is invalid or expired.' });

    client = await db.connect();
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT otp_hash, expires_at, attempts FROM password_reset_otps
       WHERE firebase_uid = $1 AND reset_token_hash IS NULL
         AND otp_hash IS NOT NULL AND expires_at > NOW()
       FOR UPDATE`,
      [accounts[0].firebase_uid],
    );
    if (!rows.length || rows[0].attempts >= 5) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'The code is invalid or expired.' });
    }

    const isValid = await bcrypt.compare(otp, rows[0].otp_hash);
    if (!isValid) {
      const attempts = rows[0].attempts + 1;
      if (attempts >= 5) {
        await client.query('DELETE FROM password_reset_otps WHERE firebase_uid = $1', [accounts[0].firebase_uid]);
      } else {
        await client.query(
          'UPDATE password_reset_otps SET attempts = $1 WHERE firebase_uid = $2',
          [attempts, accounts[0].firebase_uid],
        );
      }
      await client.query('COMMIT');
      return res.status(400).json({ error: 'The code is invalid or expired.' });
    }

    const resetToken = randomBytes(32).toString('base64url');
    await client.query(
      `UPDATE password_reset_otps
       SET otp_hash = NULL, reset_token_hash = $1,
           expires_at = NOW() + INTERVAL '${RESET_TOKEN_TTL_MINUTES} minutes', attempts = 0
       WHERE firebase_uid = $2`,
      [tokenHash(resetToken), accounts[0].firebase_uid],
    );
    await client.query('COMMIT');
    return res.json({ reset_token: resetToken, expires_in_seconds: RESET_TOKEN_TTL_MINUTES * 60 });
  } catch (error) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    console.error('[PasswordReset] OTP verification failed:', error.message);
    return res.status(500).json({ error: 'Could not verify the code.' });
  } finally {
    client?.release();
  }
};

exports.complete = async (req, res) => {
  const resetToken = typeof req.body?.reset_token === 'string' ? req.body.reset_token : '';
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  if (resetToken.length < 40 || resetToken.length > 100) {
    return res.status(400).json({ error: 'Your reset session is invalid or expired. Start again.' });
  }
  if (password.length < 8 || password.length > 128) {
    return res.status(400).json({ error: 'Password must be between 8 and 128 characters.' });
  }

  let client;
  try {
    client = await db.connect();
    await client.query('BEGIN');
    const hash = tokenHash(resetToken);
    const { rows } = await client.query(
      `SELECT firebase_uid FROM password_reset_otps
       WHERE reset_token_hash = $1 AND expires_at > NOW()
       FOR UPDATE`,
      [hash],
    );
    if (!rows.length) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Your reset session is invalid or expired. Start again.' });
    }

    await firebaseAdmin.auth().updateUser(rows[0].firebase_uid, { password });
    await firebaseAdmin.auth().revokeRefreshTokens(rows[0].firebase_uid);
    await client.query('DELETE FROM password_reset_otps WHERE firebase_uid = $1', [rows[0].firebase_uid]);
    await client.query('COMMIT');
    return res.json({ success: true, message: 'Password updated. Sign in with your new password.' });
  } catch (error) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    console.error('[PasswordReset] Password update failed:', error.message);
    return res.status(500).json({ error: 'Could not update the password. Please try again.' });
  } finally {
    client?.release();
  }
};
