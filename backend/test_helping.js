require('dotenv').config();
const db = require('./src/config/db');
async function test() {
  try {
    const limitIndex = 1;
    const offsetIndex = 2;
    const params = [20, 0];
    const { rows } = await db.query(
      `SELECT t.*,
        (SELECT COUNT(*)::int FROM helping_applications a WHERE a.task_id = t.id) AS applications_count,
        row_to_json(u.*) AS poster
       FROM helping_tasks t JOIN users u ON u.id = t.poster_id
       ORDER BY t.created_at DESC LIMIT $1 OFFSET $2`,
      params
    );
    console.log('Success:', rows.length);
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    process.exit(0);
  }
}
test();
