#!/bin/sh
set -eu

# 只有掛載的 uploads 目錄需要 root 調整擁有者；其餘步驟（等資料庫、migration、API）都以 node 身分執行。
chown -R node:node /app/uploads
chmod 750 /app/uploads

gosu node node -e '
const { Client } = require("pg");
(async () => {
  for (let attempt = 1; attempt <= 30; attempt += 1) {
    const client = new Client({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME,
      user: process.env.DB_MIGRATION_USER || process.env.DB_USER,
      password: process.env.DB_MIGRATION_USER ? process.env.DB_MIGRATION_PASS : process.env.DB_PASS,
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

gosu node node ./node_modules/typeorm/cli.js migration:run -d dist/database/data-source.js
gosu node node dist/upload/migrate-private-media.js

# migration 帳號（可建表）只在上面用一次；API 程序的環境裡不留它的密碼。
exec env -u DB_MIGRATION_USER -u DB_MIGRATION_PASS gosu node node dist/main.js
