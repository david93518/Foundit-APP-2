/* Runs the actual Nest HTTP API against an isolated PostgreSQL database.
 * Authentication fixtures are created internally; this is NOT a Google login test.
 * Run in the API container with DB_NAME=foundit_integration and SEED_SAMPLE_DATA=false.
 */
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
if (!process.env.DB_NAME?.endsWith('_integration')) {
  throw new Error('Refusing to run against a non-integration database');
}
process.env.SEED_SAMPLE_DATA = 'false';
process.env.OTP_DRIVER = 'disabled';
const { NestFactory } = require('@nestjs/core');
const { ValidationPipe } = require('@nestjs/common');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../dist/app.module');
const { AppDataSource } = require('../dist/database/data-source');
const { User } = require('../dist/common/entities/user.entity');
const { Item } = require('../dist/common/entities/item.entity');
const { SocketIoAdapter } = require('../dist/websocket/socket-io.adapter');

// Minimal Engine.IO v4 / Socket.IO v5 client for the text-only chat contract.
async function openChatSocket(origin, token, chatId) {
  const ws = new WebSocket(origin.replace(/^http/, 'ws') + '/socket.io/?EIO=4&transport=websocket');
  const packets = [];
  const waiters = [];
  const wait = predicate => {
    const index = packets.findIndex(predicate);
    if (index >= 0) return Promise.resolve(packets.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const entry = { predicate, resolve, reject };
      entry.timer = setTimeout(() => {
        const i = waiters.indexOf(entry);
        if (i >= 0) waiters.splice(i, 1);
        reject(new Error('Socket packet timeout'));
      }, 5000);
      waiters.push(entry);
    });
  };
  ws.addEventListener('message', event => {
    const packet = String(event.data);
    if (packet === '2') { ws.send('3'); return; }
    if (packet.startsWith('0')) {
      ws.send('40/chat,' + JSON.stringify({ token: 'Bearer ' + token }));
      return;
    }
    const i = waiters.findIndex(entry => entry.predicate(packet));
    if (i < 0) packets.push(packet);
    else {
      const entry = waiters.splice(i, 1)[0];
      clearTimeout(entry.timer);
      entry.resolve(packet);
    }
  });
  ws.addEventListener('close', () => {
    for (const entry of waiters.splice(0)) {
      clearTimeout(entry.timer);
      entry.reject(new Error('Chat socket disconnected'));
    }
  });
  try {
    await wait(packet => packet.startsWith('40/chat,'));
    ws.send('42/chat,' + JSON.stringify(['join', { chatId }]));
    const joined = await wait(packet => packet.startsWith('42/chat,'));
    assert.equal(JSON.parse(joined.slice(8))[0], 'joined', 'socket room join is authorized');
    return {
      waitMessage: async () => {
        const packet = await wait(value => value.startsWith('42/chat,') && JSON.parse(value.slice(8))[0] === 'message');
        return JSON.parse(packet.slice(8))[1];
      },
      close: () => ws.close(),
    };
  } catch (error) { ws.close(); throw error; }
}

(async () => {
  await AppDataSource.initialize();
  await AppDataSource.runMigrations();
  await AppDataSource.destroy();
  const app = await NestFactory.create(AppModule, { logger: ['error'] });
  app.useWebSocketAdapter(new SocketIoAdapter(app));
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
  await app.listen(0, '127.0.0.1');
  const url = await app.getUrl();
  const db = app.get(DataSource);
  const users = db.getRepository(User);
  const jwt = app.get(JwtService);
  const runId = randomUUID();
  const identities = [];
  const passed = [];
  let ownerSocket;
  const request = async (method, path, token, body, status = 200) => {
    const response = await fetch(`${url}/api/v1${path}`, {
      method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
    const data = await response.json();
    assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(data)}`);
    return data;
  };
  try {
    for (const suffix of ['owner', 'finder', 'outsider']) {
      const user = await users.save(users.create({ phone: `integration:${runId}:${suffix}`, name: `Integration ${suffix}`, status: 'active', role: 'user', isVerified: true, tokenVersion: 0 }));
      identities.push({ user, token: jwt.sign({ sub: user.id, tv: 0 }) });
    }
    const [owner, finder, outsider] = identities;
    await request('GET', '/health');
    await request('GET', '/users/me', 'forged-token', undefined, 401);
    await request('POST', '/auth/send-otp', null, { phone: '0912345678' }, 503);
    passed.push('database health, forged token rejection, SMS disabled');

    const item = (await request('POST', '/items', owner.token, {
      type: 'found', title: `Integration ${runId}`, category: '鑰匙', color: '銀色', images: [],
      latitude: 22.9999, longitude: 120.227, locationName: '臺南市測試地點', termsAccepted: true, termsVersion: '2026-10-04',
    }, 201)).data;
    assert.ok(item.id);
    const list = await request('GET', '/items?area=' + encodeURIComponent('台南市'));
    assert.ok(list.data.some(i => i.id === item.id), 'item is visible through real query');
    const stored = await db.getRepository(Item).findOneByOrFail({ id: item.id });
    assert.equal(Number(stored.latitude), 22.9999);
    await request('PATCH', `/items/${item.id}`, finder.token, { title: 'not allowed' }, 403);
    await request('PATCH', '/users/me', finder.token, { role: 'admin' }, 400);
    passed.push('create, persist coordinates, query city, reject cross-account modification and role injection');

    const chat = (await request('POST', '/chats', finder.token, { item_id: item.id }, 201)).data;
    assert.ok(chat.id);
    ownerSocket = await openChatSocket(url, owner.token, chat.id);
    await request('GET', `/chats/${chat.id}/messages`, outsider.token, undefined, 403);
    const clientMessageId = randomUUID();
    const message = (await request('POST', `/chats/${chat.id}/messages`, finder.token, { content: '請確認鑰匙特徵', type: 'TEXT', client_message_id: clientMessageId }, 201)).data;
    assert.equal((await ownerSocket.waitMessage()).id, message.id, 'peer receives saved message immediately');
    const retry = (await request('POST', `/chats/${chat.id}/messages`, finder.token, { content: '請確認鑰匙特徵', type: 'TEXT', client_message_id: clientMessageId }, 201)).data;
    assert.equal(retry.id, message.id, 'retry does not duplicate a message');
    const received = await request('GET', `/chats/${chat.id}/messages`, owner.token);
    assert.equal(received.data.filter(m => m.id === message.id).length, 1);
    await request('PATCH', `/chats/${chat.id}/read`, owner.token, { up_to_message_id: message.id });
    const chatList = await request('GET', '/chats', owner.token);
    assert.ok(chatList.data.some(c => c.id === chat.id), 'chat remains visible in the list');
    passed.push('two-account conversation, persistent messages, duplicate prevention, read receipt and private-room access');
    passed.push('WebSocket room authorization and immediate peer delivery');

    await request('PATCH', `/items/${item.id}/resolve`, owner.token, {});
    assert.equal((await db.getRepository(Item).findOneByOrFail({ id: item.id })).status, 'RESOLVED');
    await request('POST', '/auth/logout', finder.token, {}, 201);
    await request('GET', '/users/me', finder.token, undefined, 401);
    passed.push('resolve listing and revoke session after logout');
    console.log(JSON.stringify({ success: true, database: process.env.DB_NAME, passed, limitation: 'Google sign-in, external HTTPS and iPhone hardware are separate acceptance checks.' }, null, 2));
  } finally {
    ownerSocket?.close();
    // Dedicated integration database is retained for inspection; no beta data is touched.
    await app.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
