const { Pool } = require('pg');
require('dotenv').config();
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
async function run() { try { await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS deal_code TEXT UNIQUE;'); await pool.query('CREATE TABLE IF NOT EXISTS deal_redemptions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), deal_id UUID REFERENCES deals(id) ON DELETE CASCADE, user_id UUID REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(deal_id, user_id));'); console.log('Success'); } catch(e) { console.error(e); } finally { pool.end(); } }
run();
