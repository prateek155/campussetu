// backend/src/controllers/posts.controller.js
const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const cache = require('../config/redis');

// Awards 20 pts per 100 likes on a post (each 100-like milestone once)
async function awardLikeMilestones(postId, authorId) {
  try {
    const { rows: c } = await db.query('SELECT COUNT(*)::int AS n FROM post_likes WHERE post_id = $1', [postId]);
    const level = Math.floor((c[0].n || 0) / 100);
    let awarded = 0;
    for (let l = 1; l <= level; l++) {
      try {
        const reason = `post_like_milestone:${postId}:${l}`;
        const { rows } = await db.query(
          `INSERT INTO points_ledger (id, user_id, amount, reason)
           SELECT $1, $2, 20, $3
           WHERE NOT EXISTS (SELECT 1 FROM points_ledger WHERE user_id = $2 AND reason = $3)
           RETURNING id`,
          [uuidv4(), authorId, reason]
        );
        if (rows.length) awarded += 20;
      } catch (e) { if (e.code !== '23505') throw e; }
    }
    return awarded;
  } catch (_) { return 0; }
}

// ── GET /feed ────────────────────────────────────────────
exports.getFeed = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Get caller's DB id
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });
    const userId = me[0].id;

    const cacheKey = `feed:v2:page:${page}:limit:${limit}:${userId}`;
    const cached = await cache.getCache(cacheKey);
    if (cached) return res.json(JSON.parse(cached));

    const { rows } = await db.query(
      `SELECT p.*,
         jsonb_build_object(
           'id', u.id, 'name', u.name, 'photo_url', u.photo_url,
           'college', u.college, 'is_verified', u.is_verified, 'is_premium', u.is_premium
         ) AS author,
         (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id) AS likes_count,
         (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id) AS comments_count,
         EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = $1) AS is_liked
       FROM posts p
       JOIN users u ON u.id = p.author_id
       WHERE p.is_deleted = false
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, parseInt(limit), parseInt(offset)]
    );
    const result = { data: rows, page: parseInt(page) };
    await cache.setCache(cacheKey, JSON.stringify(result), 30); // 30 sec
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /posts ──────────────────────────────────────────
exports.createPost = async (req, res) => {
  try {
    const { content, image_url } = req.body;
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows } = await db.query(
      'INSERT INTO posts (author_id, content, image_url) VALUES ($1, $2, $3) RETURNING *',
      [me[0].id, content, image_url || null]
    );

    // Invalidate all feed pages for all users since a new post appears at the top
    await cache.delPattern('feed:v2:page:*');

    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /posts/:id/like ──────────────────────────────────
// Fast: responds immediately with fresh counts; milestone awarded async.
exports.toggleLike = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });
    const userId = me[0].id;

    const { rows: p } = await db.query('SELECT author_id FROM posts WHERE id = $1 AND is_deleted = false', [req.params.id]);
    if (!p.length) return res.status(404).json({ error: 'Post not found' });
    const authorId = p[0].author_id;

    const { rows: existing } = await db.query(
      'SELECT 1 FROM post_likes WHERE post_id = $1 AND user_id = $2',
      [req.params.id, userId]
    );

    let liked;
    if (existing.length) {
      await db.query('DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2', [req.params.id, userId]);
      liked = false;
    } else {
      await db.query('INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2)', [req.params.id, userId]);
      liked = true;
    }

    const { rows: c } = await db.query('SELECT COUNT(*)::int AS n FROM post_likes WHERE post_id = $1', [req.params.id]);
    if (liked && authorId !== userId) awardLikeMilestones(req.params.id, authorId).catch(() => {});

    // Invalidate feed cache — like counts changed
    await cache.delPattern('feed:v2:page:*');

    res.json({ liked, likes_count: c[0].n });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── GET /posts/:id/comments ──────────────────────────────
exports.getComments = async (req, res) => {
  try {
    const { rows } = await db.query(
      `SELECT c.*,
         jsonb_build_object('id', u.id, 'name', u.name, 'photo_url', u.photo_url) AS author
       FROM post_comments c JOIN users u ON u.id = c.author_id
       WHERE c.post_id = $1 ORDER BY c.created_at ASC`,
      [req.params.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── POST /posts/:id/comment ───────────────────────────────
exports.addComment = async (req, res) => {
  try {
    const content = (req.body.content || '').toString().trim();
    if (!content) return res.status(400).json({ error: 'Comment cannot be empty' });
    if (content.length > 500) return res.status(400).json({ error: 'Comment too long (max 500)' });
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows: post } = await db.query('SELECT id FROM posts WHERE id = $1 AND is_deleted = false', [req.params.id]);
    if (!post.length) return res.status(404).json({ error: 'Post not found' });

    const { rows: ins } = await db.query(
      'INSERT INTO post_comments (post_id, author_id, content) VALUES ($1, $2, $3) RETURNING id',
      [req.params.id, me[0].id, content]
    );
    const { rows } = await db.query(
      `SELECT c.*,
        jsonb_build_object('id', u.id, 'name', u.name, 'photo_url', u.photo_url) AS author,
        (SELECT COUNT(*)::int FROM post_comments WHERE post_id = $2) AS comments_count
       FROM post_comments c JOIN users u ON u.id = c.author_id WHERE c.id = $1`,
      [ins[0].id, req.params.id]
    );

    // Invalidate feed cache — comment counts changed
    await cache.delPattern('feed:v2:page:*');

    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ── DELETE /posts/:id ─────────────────────────────────────
exports.deletePost = async (req, res) => {
  try {
    const { rows: me } = await db.query('SELECT id FROM users WHERE firebase_uid = $1', [req.user.uid]);
    if (!me.length) return res.status(404).json({ error: 'User not found' });

    const { rows: post } = await db.query('SELECT author_id FROM posts WHERE id = $1', [req.params.id]);
    if (!post.length) return res.status(404).json({ error: 'Post not found' });
    if (post[0].author_id !== me[0].id) return res.status(403).json({ error: 'Forbidden' });

    await db.query('UPDATE posts SET is_deleted = true WHERE id = $1', [req.params.id]);

    // Invalidate feed cache — post no longer visible
    await cache.delPattern('feed:v2:page:*');

    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
