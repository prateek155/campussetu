const db = require('./src/config/db');
const { v4: uuidv4 } = require('uuid');

async function test() {
  try {
    const uidRes = await db.query('SELECT id FROM users LIMIT 1');
    const uid = uidRes.rows[0].id;
    console.log('uid:', uid);
    
    let type = 'points';
    let title = 'working';
    let description = 'noybgjb ufj hfj';
    let imageUrl = null;
    let amt = null;
    let pts = 5;
    let deadline = undefined; // simulating req.body.deadline when it's not sent

    const { rows } = await db.query(
        `INSERT INTO helping_tasks (id, title, description, image_url, type, amount, points, deadline, poster_id, status, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'open', NOW() + INTERVAL '7 days') RETURNING *`,
        [uuidv4(), title.trim(), description.trim(), imageUrl, type, amt, pts, deadline || null, uid]
    );
    console.log(rows);
  } catch (e) { console.error('Error1:', e); }
  process.exit();
}
test();
