const db = require('./backend/src/config/db');
db.query("SELECT column_name, column_default FROM information_schema.columns WHERE table_name = 'travel_rides';")
  .then(res => console.log(res.rows))
  .catch(console.error)
  .finally(() => process.exit());
