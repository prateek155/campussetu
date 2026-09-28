// PM2 Cluster config — auto-scales across all CPU cores
// Usage:
//   npm install -g pm2
//   pm2 start ecosystem.config.js
//   pm2 save && pm2 startup

module.exports = {
  apps: [
    {
      name: 'campussetu-api',
      script: './src/index.js',
      cwd: __dirname,

      // ── Clustering ──────────────────────────────────────────
      instances: 'max',       // spawn one worker per CPU core
      exec_mode: 'cluster',   // all workers share the same port

      // ── Memory & restarts ───────────────────────────────────
      max_memory_restart: '512M',   // restart if worker exceeds 512MB
      min_uptime: '10s',            // must stay up 10s to be considered stable
      max_restarts: 10,             // max restart attempts before giving up

      // ── Graceful shutdown ───────────────────────────────────
      kill_timeout: 5000,           // wait 5s for in-flight requests to finish
      listen_timeout: 10000,        // wait 10s for worker to start listening

      // ── Environment ─────────────────────────────────────────
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      // ── Logs ────────────────────────────────────────────────
      error_file: './logs/pm2-err.log',
      out_file:   './logs/pm2-out.log',
      merge_logs: true,              // single log file (not per-worker)
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',

      // ── Watch (disable in production) ───────────────────────
      watch: false,
    },
  ],
};
