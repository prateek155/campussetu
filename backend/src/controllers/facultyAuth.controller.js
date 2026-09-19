// backend/src/controllers/facultyAuth.controller.js
const db = require('../config/db');
const admin = require('../config/firebase');
const { v4: uuidv4 } = require('uuid');

// ── FACULTY: Register Request (no auth needed) ─────────────────
// Stores a pending request. Admin approves it later.
exports.registerFaculty = async (req, res) => {
  try {
    const { name, email, password, college_name, subject } = req.body;
    if (!name || !email || !password || !college_name || !subject) {
      return res.status(400).json({ error: 'All fields are required: name, email, password, college_name, subject' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Check if email already has a pending/approved request
    const { rows: existing } = await db.query(
      "SELECT id, status FROM faculty_requests WHERE email = $1",
      [email.toLowerCase().trim()]
    );
    if (existing.length) {
      const status = existing[0].status;
      if (status === 'pending') return res.status(409).json({ error: 'A request with this email is already pending approval.' });
      if (status === 'approved') return res.status(409).json({ error: 'This email is already registered as faculty. Please login.' });
      if (status === 'rejected') return res.status(409).json({ error: 'Your previous request was rejected. Please contact admin.' });
    }

    // Check if email already exists in Firebase
    try {
      await admin.auth().getUserByEmail(email.toLowerCase().trim());
      return res.status(409).json({ error: 'An account with this email already exists. Please login.' });
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }

    // Store request (password stored temporarily — will be used on approval to create Firebase user)
    // NOTE: In production, hash the password. For simplicity, storing as-is since admin creates the Firebase account.
    await db.query(
      `INSERT INTO faculty_requests (id, name, email, password, college_name, subject, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')`,
      [uuidv4(), name.trim(), email.toLowerCase().trim(), password, college_name.trim(), subject.trim()]
    );

    res.status(201).json({ message: 'Registration request submitted! You will be notified once admin approves your account.' });
  } catch (err) { res.status(500).json({ error: err.message }); }
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
  } catch (err) { res.status(500).json({ error: err.message }); }
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
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── ADMIN: Approve faculty request ───────────────────────────
exports.approveFacultyRequest = async (req, res) => {
  try {
    const { rows: req_rows } = await db.query(
      'SELECT * FROM faculty_requests WHERE id = $1 AND status = $2',
      [req.params.id, 'pending']
    );
    if (!req_rows.length) return res.status(404).json({ error: 'Request not found or already processed' });

    const request = req_rows[0];

    // Create Firebase user
    let firebaseUser;
    try {
      firebaseUser = await admin.auth().createUser({
        email: request.email,
        password: request.password,
        displayName: request.name,
      });
    } catch (e) {
      // If user already exists in Firebase, get them
      if (e.code === 'auth/email-already-exists') {
        firebaseUser = await admin.auth().getUserByEmail(request.email);
      } else throw e;
    }

    // Create user in PostgreSQL with faculty role
    const userId = uuidv4();
    await db.query(
      `INSERT INTO users (id, firebase_uid, name, email, role, college_name, subject)
       VALUES ($1, $2, $3, $4, 'faculty', $5, $6)
       ON CONFLICT (firebase_uid) DO UPDATE SET role = 'faculty', college_name = $5, subject = $6`,
      [userId, firebaseUser.uid, request.name, request.email, request.college_name, request.subject]
    );

    // Mark request as approved
    await db.query(
      "UPDATE faculty_requests SET status = 'approved' WHERE id = $1",
      [request.id]
    );

    res.json({ message: `Faculty account created for ${request.name}`, email: request.email });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── ADMIN: Reject faculty request ────────────────────────────
exports.rejectFacultyRequest = async (req, res) => {
  try {
    const { rows } = await db.query(
      "UPDATE faculty_requests SET status = 'rejected' WHERE id = $1 AND status = 'pending' RETURNING *",
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Request not found or already processed' });
    res.json({ message: 'Request rejected', request: rows[0] });
  } catch (err) { res.status(500).json({ error: err.message }); }
};
