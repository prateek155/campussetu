const { createHash, randomBytes } = require('crypto');
const db = require('../config/db');
const admin = require('../config/firebase');

const TEMPLATE_IDS = new Set([
  'modern', 'classic', 'minimal', 'elegant', 'professional',
  'creative', 'standard', 'basic', 'clean', 'simple',
  'executive', 'luxury', 'designer', 'corporate', 'tech',
  'artistic', 'futuristic', 'elite', 'platinum', 'premium',
]);
const PREMIUM_TEMPLATE_IDS = new Set([
  'executive', 'luxury', 'designer', 'corporate', 'tech',
  'artistic', 'futuristic', 'elite', 'platinum', 'premium',
]);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function normalizeDocument(body = {}) {
  const title = typeof body.title === 'string' ? body.title.trim().slice(0, 100) : '';
  const templateId = typeof body.template_id === 'string' ? body.template_id : '';
  const content = body.content;
  if (!title) return { error: 'Resume title is required' };
  if (!TEMPLATE_IDS.has(templateId)) return { error: 'Unknown resume template' };
  if (!content || typeof content !== 'object' || Array.isArray(content)) {
    return { error: 'Resume content must be an object' };
  }
  let serialized;
  try { serialized = JSON.stringify(content); } catch { return { error: 'Invalid resume content' }; }
  if (serialized.length > 100000) return { error: 'Resume content is too large' };
  if (Array.isArray(content.sections) && content.sections.length > 30) {
    return { error: 'A resume can have at most 30 sections' };
  }
  return { title, templateId, content };
}

async function getAccount(firebaseUid) {
  const { rows } = await db.query(
    'SELECT is_premium, is_banned FROM users WHERE firebase_uid = $1',
    [firebaseUid],
  );
  return rows[0] || null;
}

function canUseTemplate(templateId, account) {
  return !PREMIUM_TEMPLATE_IDS.has(templateId) || account?.is_premium === true;
}

exports.list = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT id, title, template_id, content, created_at, updated_at
       FROM resume_documents WHERE firebase_uid = $1
       ORDER BY updated_at DESC LIMIT 50`,
      [req.user.uid],
    );
    res.json({ data: rows });
  } catch (error) {
    console.error('[Resume] list failed:', error.message);
    res.status(500).json({ error: 'Could not load resumes' });
  }
};

exports.get = async (req, res) => {
  try {
    if (!UUID_RE.test(req.params.id)) return res.status(404).json({ error: 'Resume not found' });
    const { rows } = await db.query(
      `SELECT id, title, template_id, content, created_at, updated_at
       FROM resume_documents WHERE id = $1 AND firebase_uid = $2`,
      [req.params.id, req.user.uid],
    );
    if (!rows.length) return res.status(404).json({ error: 'Resume not found' });
    res.json(rows[0]);
  } catch (error) {
    console.error('[Resume] get failed:', error.message);
    res.status(500).json({ error: 'Could not load this resume' });
  }
};

exports.create = async (req, res) => {
  try {
    const document = normalizeDocument(req.body);
    if (document.error) return res.status(400).json({ error: document.error });
    const account = await getAccount(req.user.uid);
    if (!account || account.is_banned) return res.status(403).json({ error: 'Resume access is unavailable for this account' });
    if (!canUseTemplate(document.templateId, account)) return res.status(403).json({ error: 'This template requires Premium' });
    const { rows: countRows } = await db.query(
      'SELECT COUNT(*)::int AS count FROM resume_documents WHERE firebase_uid = $1',
      [req.user.uid],
    );
    if (countRows[0].count >= 50) return res.status(409).json({ error: 'You have reached the 50 saved resume limit' });

    const { rows } = await db.query(
      `INSERT INTO resume_documents (firebase_uid, title, template_id, content)
       VALUES ($1, $2, $3, $4::jsonb)
       RETURNING id, title, template_id, content, created_at, updated_at`,
      [req.user.uid, document.title, document.templateId, JSON.stringify(document.content)],
    );
    res.status(201).json(rows[0]);
  } catch (error) {
    console.error('[Resume] create failed:', error.message);
    res.status(500).json({ error: 'Could not save this resume' });
  }
};

exports.update = async (req, res) => {
  try {
    if (!UUID_RE.test(req.params.id)) return res.status(404).json({ error: 'Resume not found' });
    const document = normalizeDocument(req.body);
    if (document.error) return res.status(400).json({ error: document.error });
    const account = await getAccount(req.user.uid);
    if (!account || account.is_banned) return res.status(403).json({ error: 'Resume access is unavailable for this account' });
    const { rows: existing } = await db.query(
      'SELECT template_id FROM resume_documents WHERE id = $1 AND firebase_uid = $2',
      [req.params.id, req.user.uid],
    );
    if (!existing.length) return res.status(404).json({ error: 'Resume not found' });
    if (document.templateId !== existing[0].template_id && !canUseTemplate(document.templateId, account)) {
      return res.status(403).json({ error: 'This template requires Premium' });
    }

    const { rows } = await db.query(
      `UPDATE resume_documents SET title = $1, template_id = $2, content = $3::jsonb, updated_at = NOW()
       WHERE id = $4 AND firebase_uid = $5
       RETURNING id, title, template_id, content, created_at, updated_at`,
      [document.title, document.templateId, JSON.stringify(document.content), req.params.id, req.user.uid],
    );
    if (!rows.length) return res.status(404).json({ error: 'Resume not found' });
    res.json(rows[0]);
  } catch (error) {
    console.error('[Resume] update failed:', error.message);
    res.status(500).json({ error: 'Could not update this resume' });
  }
};

exports.remove = async (req, res) => {
  try {
    if (!UUID_RE.test(req.params.id)) return res.status(404).json({ error: 'Resume not found' });
    const { rowCount } = await db.query(
      'DELETE FROM resume_documents WHERE id = $1 AND firebase_uid = $2',
      [req.params.id, req.user.uid],
    );
    if (!rowCount) return res.status(404).json({ error: 'Resume not found' });
    res.json({ success: true });
  } catch (error) {
    console.error('[Resume] remove failed:', error.message);
    res.status(500).json({ error: 'Could not delete this resume' });
  }
};

exports.createHandoff = async (req, res) => {
  try {
    const templateId = typeof req.body.template_id === 'string' ? req.body.template_id : '';
    const resumeId = typeof req.body.resume_id === 'string' ? req.body.resume_id : null;
    if (!TEMPLATE_IDS.has(templateId)) return res.status(400).json({ error: 'Unknown resume template' });
    if (resumeId && !UUID_RE.test(resumeId)) return res.status(404).json({ error: 'Resume not found' });

    const account = await getAccount(req.user.uid);
    if (!account || account.is_banned) return res.status(403).json({ error: 'Resume access is unavailable for this account' });
    if (resumeId) {
      const { rows } = await db.query(
        'SELECT template_id FROM resume_documents WHERE id = $1 AND firebase_uid = $2',
        [resumeId, req.user.uid],
      );
      if (!rows.length) return res.status(404).json({ error: 'Resume not found' });
      if (rows[0].template_id !== templateId) return res.status(400).json({ error: 'Resume template does not match' });
    } else if (!canUseTemplate(templateId, account)) {
      return res.status(403).json({ error: 'This template requires Premium' });
    }

    const code = randomBytes(32).toString('base64url');
    const codeHash = createHash('sha256').update(code).digest('hex');
    await db.query('DELETE FROM resume_browser_handoffs WHERE expires_at <= NOW()');
    await db.query(
      `INSERT INTO resume_browser_handoffs (code_hash, firebase_uid, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '5 minutes')`,
      [codeHash, req.user.uid],
    );
    res.status(201).json({ code, expires_in_seconds: 300 });
  } catch (error) {
    console.error('[Resume] handoff creation failed:', error.message);
    res.status(500).json({ error: 'Could not open the web editor' });
  }
};

exports.exchangeHandoff = async (req, res) => {
  try {
    const code = typeof req.body.code === 'string' ? req.body.code : '';
    if (code.length < 40 || code.length > 100) return res.status(400).json({ error: 'Invalid or expired editor link' });
    const codeHash = createHash('sha256').update(code).digest('hex');
    const { rows } = await db.query(
      `DELETE FROM resume_browser_handoffs
       WHERE code_hash = $1 AND expires_at > NOW()
       RETURNING firebase_uid`,
      [codeHash],
    );
    if (!rows.length) return res.status(401).json({ error: 'This editor link has expired. Reopen it from CampusSetu.' });

    const account = await getAccount(rows[0].firebase_uid);
    if (!account || account.is_banned) return res.status(403).json({ error: 'Resume access is unavailable for this account' });
    const customToken = await admin.auth().createCustomToken(rows[0].firebase_uid);
    res.json({ token: customToken });
  } catch (error) {
    console.error('[Resume] handoff exchange failed:', error.message);
    res.status(500).json({ error: 'Could not sign in to the web editor' });
  }
};
