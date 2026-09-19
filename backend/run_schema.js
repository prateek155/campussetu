const fs = require('fs');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
  try {
    const schema = fs.readFileSync('schema.sql', 'utf8');
    await pool.query(schema);
    
    // Also run the block for status check
    await pool.query(`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'helping_tasks_status_hold_check') THEN
          ALTER TABLE helping_tasks ADD CONSTRAINT helping_tasks_status_hold_check CHECK (status IN ('open','assigned','completed','cancelled','on_hold'));
        END IF;
      END $$;
    `);

    console.log('Schema applied successfully!');
  } catch (e) {
    console.error(e);
  } finally {
    pool.end();
  }
}
run();
