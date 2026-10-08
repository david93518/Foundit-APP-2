#!/bin/sh
set -eu

node -e '
const { Client } = require("pg");
(async () => {
  for (let attempt = 1; attempt <= 30; attempt += 1) {
    const client = new Client({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
    });
    try {
      await client.connect();
      await client.query("SELECT 1");
      await client.end();
      process.exit(0);
    } catch (error) {
      try { await client.end(); } catch (_) {}
      if (attempt === 30) {
        console.error(error && error.message ? error.message : error);
        process.exit(1);
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
})();
'

node ./node_modules/typeorm/cli.js migration:run -d dist/database/data-source.js

chown -R node:node /app/uploads
exec gosu node node dist/main.js
