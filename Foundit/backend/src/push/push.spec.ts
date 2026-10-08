import { ConfigService } from '@nestjs/config';
import { createVerify, generateKeyPairSync } from 'crypto';
import { Repository } from 'typeorm';
import { PushMessage, PushService } from './push.service';
import { ChatPushService } from '../chats/chat-push.service';
import { NotificationsService } from '../notifications/notifications.service';
import { Chat } from '../common/entities/chat.entity';
import { Message, MessageType } from '../common/entities/message.entity';
import { User } from '../common/entities/user.entity';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const account = {
  project_id: 'foundit-test',
  client_email: 'push@foundit-test.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
};

type Call = { url: string; headers: Record<string, string>; body: string };

class RecordingPush extends PushService {
  calls: Call[] = [];
  replies: Array<{ status: number; body: string }> = [];
  protected async post(url: string, headers: Record<string, string>, body: string) {
    this.calls.push({ url, headers, body });
    if (url.includes('oauth2')) return { status: 200, body: JSON.stringify({ access_token: 'at-1', expires_in: 3600 }) };
    return this.replies.shift() ?? { status: 200, body: '{}' };
  }
}

function push(env: Record<string, string>): RecordingPush {
  return new RecordingPush({ get: (key: string) => env[key] } as unknown as ConfigService);
}

const message: PushMessage = {
  title: '小明 · 藍色後背包',
  body: '我在捷運站撿到了',
  data: { type: 'chat_message', chat_id: 'c1' },
  collapseKey: 'chat-c1',
  badge: 3,
};

describe('PushService', () => {
  it('stays off without a service account and never calls the network', async () => {
    const service = push({});
    expect(service.enabled).toBe(false);
    expect(await service.send('device', message)).toBe('disabled');
    expect(service.calls).toHaveLength(0);
  });

  it('signs a service-account JWT and sends an FCM v1 message', async () => {
    const service = push({ FCM_SERVICE_ACCOUNT_JSON: Buffer.from(JSON.stringify(account)).toString('base64') });
    expect(await service.send('device-token', message)).toBe('sent');
    expect(await service.send('device-token', message)).toBe('sent');

    const [auth, first, second] = service.calls;
    expect(service.calls.filter((c) => c.url.includes('oauth2'))).toHaveLength(1); // token cached
    const assertion = new URLSearchParams(auth.body).get('assertion')!;
    const [header, claims, signature] = assertion.split('.');
    expect(createVerify('RSA-SHA256').update(`${header}.${claims}`).verify(publicKey, signature, 'base64url')).toBe(true);
    expect(JSON.parse(Buffer.from(claims, 'base64url').toString())).toMatchObject({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    });

    expect(first.url).toBe('https://fcm.googleapis.com/v1/projects/foundit-test/messages:send');
    expect(first.headers.authorization).toBe('Bearer at-1');
    expect(JSON.parse(first.body).message).toMatchObject({
      token: 'device-token',
      notification: { title: '小明 · 藍色後背包', body: '我在捷運站撿到了' },
      data: { type: 'chat_message', chat_id: 'c1' },
      android: { notification: { tag: 'chat-c1' } },
      apns: { payload: { aps: { badge: 3, 'thread-id': 'chat-c1' } } },
    });
    expect(second.url).toBe(first.url);
  });

  it('reports a token the device no longer owns as invalid, other errors as failed', async () => {
    const service = push({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify(account) });
    service.replies.push(
      { status: 404, body: '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}' },
      { status: 400, body: '{"error":{"message":"The registration token is not a valid FCM registration token"}}' },
      { status: 503, body: '{"error":{"status":"UNAVAILABLE"}}' },
    );
    expect(await service.send('a', message)).toBe('invalid-token');
    expect(await service.send('b', message)).toBe('invalid-token');
    expect(await service.send('c', message)).toBe('failed');
  });
});

describe('ChatPushService', () => {
  const sender = { id: 's', name: '小明', status: 'active', fcmToken: 'sender-device' } as User;
  const recipient = { id: 'r', name: '物主', status: 'active', fcmToken: 'owner-device' } as User;
  const chat = { id: 'c1', qrItem: { name: '藍色後背包' }, item: null, participants: [sender, recipient] } as unknown as Chat;
  let sent: Array<[string | null | undefined, PushMessage]>;
  let result: string;
  let update: jest.Mock;
  let createNotification: jest.Mock;
  let service: ChatPushService;

  beforeEach(() => {
    sent = [];
    result = 'sent';
    update = jest.fn();
    createNotification = jest.fn();
    const fake = {
      enabled: true,
      send: async (token: string | null | undefined, m: PushMessage) => {
        sent.push([token, m]);
        return result;
      },
    } as unknown as PushService;
    service = new ChatPushService(
      fake,
      { create: createNotification } as unknown as NotificationsService,
      { update } as unknown as Repository<User>,
    );
  });

  it('pushes only to the other participant with sender, subject and unread badge', async () => {
    const msg = { content: '  我在捷運站\n撿到了  ', type: MessageType.TEXT } as Message;
    await service.newMessage(chat, msg, sender, async () => 4);
    expect(sent).toHaveLength(1);
    expect(sent[0][0]).toBe('owner-device');
    expect(sent[0][1]).toMatchObject({
      title: '小明 · 藍色後背包',
      body: '我在捷運站 撿到了',
      data: { type: 'chat_message', chat_id: 'c1' },
      badge: 4,
    });
  });

  it('does not reveal image contents and clears a token FCM rejected', async () => {
    result = 'invalid-token';
    await service.newMessage(chat, { content: 'https://x/y.jpg', type: MessageType.IMAGE } as Message, sender, async () => 1);
    expect(sent[0][1].body).toBe('傳送了一張照片');
    expect(update).toHaveBeenCalledWith({ id: 'r', fcmToken: 'owner-device' }, { fcmToken: null });
  });

  it('leaves an in-app notice and a push when someone scans a tag', async () => {
    await service.tagScanned(chat, sender, '藍色後背包');
    expect(createNotification).toHaveBeenCalledWith(expect.objectContaining({ userId: 'r', chatId: 'c1', type: 'QR_SCAN' }));
    expect(sent[0][1].title).toBe('有人掃到你的防丟牌');
  });
});
