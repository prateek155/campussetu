// backend/src/controllers/facultyAuth.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');

async function deleteFirebaseUserQuietly(uid) {
  if (!uid) return;
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    console.warn('Could not remove unlinked faculty Firebase account:', err.code || 'unknown error');
  }
}

// ── FACULTY: Register Request (no auth needed) ─────────────────
// Firebase owns the password credential. Pending accounts are disabled until approval.
exports.registerFaculty = async (req, res) => {
  let newlyCreatedUid = null;
  let requestSaved = false;

  try {
    const { name, email, password, college_name, subject } = req.body;
    if (![name, email, password, college_name, subject].every((value) => typeof value === 'string' && value.trim())) {
      return res.status(400).json({ error: 'All fields are required: name, email, password, college_name, subject' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const { rows: existing } = await db.query(
      'SELECT id, status, firebase_uid FROM faculty_requests WHERE email = $1',
      [normalizedEmail]
    );
    const previousRequest = existing[0];

    if (previousRequest?.status === 'pending') {
      return res.status(409).json({ error: 'A request with this email is already pending approval.' });
    }
    if (previousRequest?.status === 'approved') {
      return res.status(409).json({ error: 'This email is already registered as faculty. Please login.' });
    }

    let firebaseUser = null;

    // Reuse this request's disabled Firebase account after a rejection, if it still exists.
    if (previousRequest?.status === 'rejected' && previousRequest.firebase_uid) {
      try {
        const linkedUser = await admin.auth().getUser(previousRequest.firebase_uid);
        if (linkedUser.email?.toLowerCase() !== normalizedEmail) {
          return res.status(409).json({ error: 'An account with this email already exists. Please login.' });
        }
        firebaseUser = await admin.auth().updateUser(linkedUser.uid, {
          password,
          displayName: name.trim(),
          disabled: true,
        });
      } catch (err) {
        if (err.code !== 'auth/user-not-found') throw err;
      }
    }

    if (!firebaseUser) {
      // Do not claim an unrelated Firebase account with the same email.
      try {
        await admin.auth().getUserByEmail(normalizedEmail);
        return res.status(409).json({ error: 'An account with this email already exists. Please login.' });
      } catch (err) {
        if (err.code !== 'auth/user-not-found') throw err;
      }

      try {
        firebaseUser = await admin.auth().createUser({
          email: normalizedEmail,
          password,
          displayName: name.trim(),
          disabled: true,
        });
        newlyCreatedUid = firebaseUser.uid;
      } catch (err) {
        if (err.code === 'auth/email-already-exists') {
          return res.status(409).json({ error: 'An account with this email already exists. Please login.' });
        }
        throw err;
      }
    }

    const requestId = previousRequest?.id || uuidv4();
    const { rows: saved } = await db.query(
      `INSERT INTO faculty_requests (id, firebase_uid, name, email, college_name, subject, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       ON CONFLICT (email) DO UPDATE SET
         firebase_uid = EXCLUDED.firebase_uid,
         name = EXCLUDED.name,
         college_name = EXCLUDED.college_name,
         subject = EXCLUDED.subject,
         status = 'pending',
         created_at = NOW()
       WHERE faculty_requests.status = 'rejected'
       RETURNING id`,
      [requestId, firebaseUser.uid, name.trim(), normalizedEmail, college_name.trim(), subject.trim()]
    );

    if (!saved.length) {
      await deleteFirebaseUserQuietly(newlyCreatedUid);
      newlyCreatedUid = null;
      return res.status(409).json({ error: 'A request with this email is already pending or approved.' });
    }

    requestSaved = true;
    res.status(201).json({ message: 'Registration request submitted! You will be notified once admin approves your account.' });
  } catch (err) {
    if (!requestSaved) await deleteFirebaseUserQuietly(newlyCreatedUid);
    if (err.code === '23505') {
      return res.status(409).json({ error: 'A request with this email is already pending or approved.' });
    }
    res.status(500).json({ error: 'Unable to submit faculty registration request' });
  }
};

// ── FACULTY: Login Check (called after Firebase login) ────────
// Verifies user has faculty role in DB
exports.loginCheck = async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, name, email, role, college_name, subject FROM users WHERE firebase_uid = $1',
      [req.user.uid]
    );
    if (!rows.length) return res.status(403).json({ error: 'Account not found. Please contact admin.' });
    if (rows[0].role !== 'faculty' && !rows[0].is_admin) {
      return res.status(403).json({ error: 'Faculty access required.' });
    }
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: 'Unable to verify faculty access' }); }
};

// ── ADMIN: Get all faculty requests ──────────────────────────
exports.getFacultyRequests = async (req, res) => {
  try {
    const { status = 'pending' } = req.query;
    const { rows } = await db.query(
      `SELECT id, name, email, college_name, subject, status, created_at
       FROM faculty_requests WHERE status = $1 ORDER BY created_at DESC`,
      [status]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: 'Unable to load faculty requests' }); }
};

// ── ADMIN: Approve faculty request ───────────────────────────
exports.approveFacultyRequest = async (req, res) => {
  let client;
  let enabledFirebaseUid = null;
  let committed = false;
  try {
    client = await db.connect();
    await client.query('BEGIN');
    const { rows: requests } = await client.query(
      `SELECT id, firebase_uid, name, email, college_name, subject
       FROM faculty_requests WHERE id = $1 AND status = 'pending' FOR UPDATE`,
      [req.params.id]
    );
    if (!requests.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Request not found or already processed' });
    }

    const request = requests[0];
    if (!request.firebase_uid) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This legacy request must be submitted again before approval.' });
    }

    // Enable the credential created during registration, then grant the DB role.
    await admin.auth().updateUser(request.firebase_uid, { disabled: false });
    enabledFirebaseUid = request.firebase_uid;
    const userId = uuidv4();
    await client.query(
      `INSERT INTO users (id, firebase_uid, name, email, role, college_name, subject)
       VALUES ($1, $2, $3, $4, 'faculty', $5, $6)
       ON CONFLICT (firebase_uid) DO UPDATE SET role = 'faculty', college_name = $5, subject = $6`,
      [userId, request.firebase_uid, request.name, request.email, request.college_name, request.subject]
    );
    await client.query(
      "UPDATE faculty_requests SET status = 'approved' WHERE id = $1",
      [request.id]
    );
    await client.query('COMMIT');
    committed = true;

    res.json({ message: `Faculty account approved for ${request.name}`, email: request.email });
  } catch (err) {
    if (client) await client.query('ROLLBACK').catch(() => {});
    if (enabledFirebaseUid && !committed) {
      await admin.auth().updateUser(enabledFirebaseUid, { disabled: true }).catch(() => {});
    }
    console.error('Faculty approval failed:', err.code || 'unknown error');
    res.status(500).json({ error: 'Unable to approve faculty request' });
  } finally {
    client?.release();
  }
};

// ── ADMIN: Reject faculty request ────────────────────────────
exports.rejectFacultyRequest = async (req, res) => {
  try {
    const { rows } = await db.query(
      `UPDATE faculty_requests SET status = 'rejected'
       WHERE id = $1 AND status = 'pending'
       RETURNING id, firebase_uid, name, email, college_name, subject, status, created_at`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Request not found or already processed' });

    const request = rows[0];
    if (request.firebase_uid) {
      try {
        await admin.auth().updateUser(request.firebase_uid, { disabled: true });
      } catch (err) {
        // The account was created disabled; keep rejection safe if Firebase is unavailable.
        console.warn('Could not disable rejected faculty Firebase account:', err.code || 'unknown error');
      }
    }

    const { id, name, email, college_name, subject, status, created_at } = request;
    res.json({ message: 'Request rejected', request: { id, name, email, college_name, subject, status, created_at } });
  } catch (err) { res.status(500).json({ error: 'Unable to reject faculty request' }); }
};
