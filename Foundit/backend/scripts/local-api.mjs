// Runs the built API on this machine with an in-memory PostgreSQL (PGlite), so the sticker and LINE endpoints can be
// tried without Docker or a Render service. Nothing is saved: stop it and the data is gone.
//
//   npm ci
//   npm i --no-save @electric-sql/pglite @electric-sql/pglite-socket
//   npm run build
//   node scripts/local-api.mjs
//
// It seeds an admin and two users, prints a Bearer token for each, creates one batch of 3 blank stickers, and prints
// ready-to-paste curl commands. Swagger UI (http://localhost:3000/api/docs) accepts the same tokens under "Authorize".
// The database is PGlite, which serves one session at a time: two requests at the same instant can fail with a 500.
// That is a limit of this runner, not of the API; try things one after another.

import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { randomBytes } from 'node:crypto';

const require = createRequire(import.meta.url);
const { PGlite } = await import('@electric-sql/pglite');
const { uuid_ossp } = await import('@electric-sql/pglite/contrib/uuid_ossp');
const { PGLiteSocketServer } = await import('@electric-sql/pglite-socket');
const jwt = require('jsonwebtoken');

const PORT = process.env.PORT ?? '3000';
const DB_PORT = 54329;
const SECRET = randomBytes(32).toString('hex');
const CHANNEL_SECRET = 'local-channel-secret';
const LINE_PORT = 3998;
const BASE = `http://localhost:${PORT}`;

// A stand-in for api.line.me: prints what the bot would send back to LINE, so the link it hands out is visible.
const lineMock = createServer((req, res) => {
  let data = '';
  req.on('data', (chunk) => { data += chunk; });
  req.on('end', () => {
    try {
      const { messages = [] } = JSON.parse(data || '{}');
      for (const m of messages) {
        const uri = m.contents?.footer?.contents?.[0]?.action?.uri;
        console.log(`\n[LINE reply] ${uri ? `link: ${uri}` : String(m.text).replace(/\n/g, ' / ')}`);
      }
    } catch { /* not a reply */ }
    res.setHeader('content-type', 'application/json');
    res.end('{}');
  });
});
await new Promise((resolve) => lineMock.listen(LINE_PORT, '127.0.0.1', resolve));

const db = new PGlite({ extensions: { uuid_ossp } });
await db.waitReady;
const server = new PGLiteSocketServer({ db, port: DB_PORT, host: '127.0.0.1' });
await server.start();

const app = spawn('node', ['dist/main.js'], {
  stdio: ['ignore', 'pipe', 'pipe'],
  env: {
    ...process.env,
    NODE_ENV: 'development', // lets TypeORM create the tables itself
    DB_HOST: '127.0.0.1', DB_PORT: String(DB_PORT), DB_NAME: 'postgres', DB_USER: 'postgres', DB_PASS: 'local',
    JWT_SECRET: SECRET, PORT, APP_BASE_URL: BASE,
    LINE_CHANNEL_SECRET: CHANNEL_SECRET, LINE_CHANNEL_ACCESS_TOKEN: 'local-access-token',
    LINE_FINDER_URL: 'http://localhost:8080', LINE_API_BASE: `http://127.0.0.1:${LINE_PORT}`,
  },
});
let log = '';
const started = new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`API did not start in 2 minutes\n${log.slice(-2000)}`)), 120_000);
  const onData = (chunk) => {
    log += chunk;
    if (log.includes('Server running')) { clearTimeout(timer); resolve(); }
  };
  app.stdout.on('data', onData);
  app.stderr.on('data', onData);
  app.on('exit', (code) => reject(new Error(`API exited with ${code}\n${log.slice(-2000)}`)));
});

const stop = async () => { app.kill('SIGTERM'); lineMock.close(); await server.stop().catch(() => {}); await db.close().catch(() => {}); process.exit(0); };
process.on('SIGINT', stop);
process.on('SIGTERM', stop);

try {
  await started;
  const person = async (email, role) => {
    const { rows } = await db.query('insert into users (email, phone, name, role) values ($1,$2,$3,$4) returning id', [email, `local-${email}`, email.split('@')[0], role]);
    return jwt.sign({ sub: rows[0].id, tv: 0 }, SECRET, { expiresIn: '7d' });
  };
  const admin = await person('admin@local.test', 'admin');
  const alice = await person('alice@local.test', 'user');
  const bob = await person('bob@local.test', 'user');
  const made = await (await fetch(`${BASE}/api/v1/admin/qr/batches`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${admin}` },
    body: JSON.stringify({ label: '本機測試', place: 'localhost', count: 3 }),
  })).json();
  const [c1, c2] = made.codes.map((c) => c.code);

  console.log(`
API:      ${BASE}/api/v1      Swagger: ${BASE}/api/docs
Sticker landing page: ${BASE}/qr/${c1}
Blank stickers: ${made.codes.map((c) => c.code).join('  ')}

ADMIN=${admin}
ALICE=${alice}
BOB=${bob}

# Is it bound?                 (unbound -> active)
curl ${BASE}/api/v1/qr/status/${c1}
# Alice scans it in the App and binds it
curl -X POST ${BASE}/api/v1/qr/bind -H "authorization: Bearer $ALICE" -H 'content-type: application/json' -d '{"code":"${c1}","name":"藍色後背包"}'
# Bob cannot take it (409)
curl -X POST ${BASE}/api/v1/qr/bind -H "authorization: Bearer $BOB" -H 'content-type: application/json' -d '{"code":"${c1}","name":"偷綁"}'
# A person presses "我撿到東西了" in LINE. This is what LINE would POST, signed with the channel secret;
# the reply the bot sends back is printed above (the "link: ..." line has the token after t=).
BODY='{"destination":"Ubot","events":[{"type":"postback","replyToken":"rt1","source":{"type":"user","userId":"U0123456789abcdef0123456789abcdef"},"postback":{"data":"action=found"}}]}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac '${CHANNEL_SECRET}' -binary | base64)
curl -X POST ${BASE}/api/v1/line/webhook -H "x-line-signature: $SIG" -H 'content-type: application/json' -d "$BODY"
# (the same with the sticker code as a text message: "type":"message","message":{"type":"text","text":"${c1}"})
# The finder leaves a message with that token, no login
curl -X POST ${BASE}/api/v1/line/links/<TOKEN>/notify -H 'content-type: application/json' -d '{"code":"${c1}","message":"我在總圖二樓撿到","contact":"0912-345-678"}'
# Alice sees it
curl ${BASE}/api/v1/notifications -H "authorization: Bearer $ALICE"
# Another blank sticker, for a second try: ${c2}

Ctrl-C to stop (all data is dropped).`);
} catch (error) {
  console.error(error.message);
  await stop();
}
