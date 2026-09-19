const fs = require('fs');
const path = require('path');
const p = path.join(__dirname, 'src', 'controllers', 'users.controller.js');
let content = fs.readFileSync(p, 'utf8');

const dealCodeLogic = 
function genDealCode(name) {
  let initials = 'XX';
  if (name) {
    const parts = name.trim().split(/\\s+/);
    if (parts.length >= 2) {
      initials = (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (parts[0].length >= 1) {
      initials = parts[0].substring(0, 2).toUpperCase().padEnd(2, 'X');
    }
  }
  const digits = Math.floor(1000 + Math.random() * 9000);
  return \\\\;
}

async function ensureDealCode(userId, name) {
  const { rows } = await db.query('SELECT deal_code FROM users WHERE id = ', [userId]);
  if (!rows.length || rows[0].deal_code) return;
  for (let i = 0; i < 8; i++) {
    try {
      const code = genDealCode(name);
      const { rows: u } = await db.query('UPDATE users SET deal_code =  WHERE id =  AND deal_code IS NULL RETURNING deal_code', [code, userId]);
      if (u.length) return;
    } catch (e) { if (e.code !== '23505') throw e; }
  }
}
;

content = content.replace('// Awards 25 signup bonus once', dealCodeLogic + '\n// Awards 25 signup bonus once');

content = content.replace(/await ensureCampusId\(id\);/g, 'await ensureCampusId(id);\n    await ensureDealCode(id, rows[0].name);');
content = content.replace(/await ensureCampusId\(rows\[0\]\.id\);/g, 'await ensureCampusId(rows[0].id);\n      await ensureDealCode(rows[0].id, rows[0].name);');
content = content.replace(/await ensureCampusId\(created\[0\]\.id\);/g, 'await ensureCampusId(created[0].id);\n    await ensureDealCode(created[0].id, created[0].name);');

fs.writeFileSync(p, content);
console.log('users.controller.js updated');
