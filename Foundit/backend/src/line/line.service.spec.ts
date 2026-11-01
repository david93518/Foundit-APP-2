import { GoneException, HttpException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { LineService, LINK_USES, LINKS_PER_HOUR, NOTICES_PER_HOUR } from './line.service';
import { LineLink } from '../common/entities/line-link.entity';
import { NotificationType } from '../common/entities/notification.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';

const LINE_USER = 'U0123456789abcdef0123456789abcdef';
const owner = { id: 'owner-1', status: 'active', fcmToken: 'fcm-1' } as User;
const tag = { id: 'qr-1', name: '藍色後背包' } as QrItem;
const sha = (v: string) => createHash('sha256').update(v).digest('hex');

function setup(over: { link?: Partial<LineLink> | null; recentLinks?: number; recentNotices?: number; pushEnabled?: boolean } = {}) {
  const saved: object[] = [];
  const link = over.link === null ? null : ({ tokenHash: '', lineUserHash: 'hash', expiresAt: new Date(Date.now() + 60_000), usesLeft: 3, ...over.link } as LineLink);
  const linkRepo = {
    count: jest.fn().mockResolvedValue(over.recentLinks ?? 0),
    create: jest.fn((v: object) => v),
    save: jest.fn(async (v: object) => {
      saved.push(v);
      return v;
    }),
    findOne: jest.fn().mockResolvedValue(link),
  };
  const manager = {
    findOne: jest.fn().mockResolvedValue(link),
    count: jest.fn().mockResolvedValue(over.recentNotices ?? 0),
    save: jest.fn(async (v: object) => {
      saved.push(v);
      return v;
    }),
    create: jest.fn((_: unknown, v: object) => v),
  };
  const dataSource = { transaction: jest.fn(async (fn: (m: typeof manager) => unknown) => fn(manager)) };
  const qr = { scanByCode: jest.fn().mockResolvedValue({ qrItem: tag, owner }) };
  const notifications = { create: jest.fn().mockResolvedValue({}) };
  const push = { enabled: over.pushEnabled ?? false, send: jest.fn().mockResolvedValue('sent') };
  const config = { get: (k: string, d?: string) => (k === 'LINE_CHANNEL_SECRET' ? 'channel-secret' : d) } as unknown as ConfigService;
  const service = new LineService(linkRepo as never, dataSource as never, qr as never, notifications as never, push as never, config);
  return { service, linkRepo, manager, dataSource, qr, notifications, push, saved, link };
}

describe('LineService.issueLink', () => {
  it('stores only hashes and returns a usable token', async () => {
    const t = setup();
    const { token, uses, expiresAt } = await t.service.issueLink(LINE_USER, 30);
    expect(token).toMatch(/^[A-Za-z0-9_-]{32}$/);
    expect(uses).toBe(LINK_USES);
    expect(expiresAt.getTime()).toBeGreaterThan(Date.now() + 29 * 60_000);
    const stored = t.saved[0] as LineLink;
    expect(stored.tokenHash).toBe(sha(token));
    expect(stored.usesLeft).toBe(LINK_USES);
    expect(JSON.stringify(stored)).not.toContain(token);
    expect(JSON.stringify(stored)).not.toContain(LINE_USER);
  });

  it('clamps the lifetime to 5 minutes – 24 hours', async () => {
    const t = setup();
    expect((await t.service.issueLink(LINE_USER, 1)).expiresAt.getTime()).toBeLessThan(Date.now() + 6 * 60_000);
    expect((await t.service.issueLink(LINE_USER, 99999)).expiresAt.getTime()).toBeLessThan(Date.now() + 1441 * 60_000);
  });

  it('limits how many links one person can get per hour', async () => {
    const t = setup({ recentLinks: LINKS_PER_HOUR });
    await expect(t.service.issueLink(LINE_USER)).rejects.toMatchObject({ status: 429 });
    expect(t.saved).toHaveLength(0);
  });
});

describe('LineService.status', () => {
  it.each([
    ['ok', {}, 'ok'],
    ['expired', { expiresAt: new Date(Date.now() - 1000) }, 'expired'],
    ['used', { usesLeft: 0 }, 'used'],
  ])('reports %s', async (_n, link, expected) => {
    expect((await setup({ link }).service.status('tok')).status).toBe(expected);
  });

  it('reports invalid for an unknown token', async () => {
    expect((await setup({ link: null }).service.status('tok')).status).toBe('invalid');
  });
});

describe('LineService.notifyOwner', () => {
  const dto = { code: 'K7M2P9', message: ' 我在圖書館撿到 ', contact: ' 0912 ' };

  it('spends one use, records the notice and tells the owner', async () => {
    const t = setup({ pushEnabled: true });
    const r = await t.service.notifyOwner('tok', dto);
    expect(r).toEqual({ name: '藍色後背包', usesLeft: 2 });
    expect(t.link?.usesLeft).toBe(2);
    expect(t.saved).toContainEqual(expect.objectContaining({ qrItemId: 'qr-1', message: '我在圖書館撿到', contact: '0912' }));
    expect(t.notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'owner-1',
        type: NotificationType.QR_SCAN,
        title: '有人撿到你的「藍色後背包」',
        content: expect.stringContaining('0912'),
      }),
    );
    expect(t.push.send).toHaveBeenCalledWith('fcm-1', expect.objectContaining({ title: '有人撿到你的「藍色後背包」' }));
  });

  it('never exposes the finder LINE id to the owner', async () => {
    const t = setup();
    await t.service.notifyOwner('tok', dto);
    expect(JSON.stringify(t.notifications.create.mock.calls)).not.toContain('hash');
  });

  it('spends a use on a wrong code (6 characters are guessable) and says how many are left', async () => {
    const t = setup();
    t.qr.scanByCode.mockRejectedValue(new NotFoundException('QR Code 無效或已失效'));
    await expect(t.service.notifyOwner('tok', dto)).rejects.toThrow(/還能再試 2 次/);
    expect(t.link?.usesLeft).toBe(2);
    expect(t.saved.some((s) => 'qrItemId' in s)).toBe(false);
    expect(t.notifications.create).not.toHaveBeenCalled();
  });

  it('tells the finder when the last try was a wrong code', async () => {
    const t = setup({ link: { usesLeft: 1 } });
    t.qr.scanByCode.mockRejectedValue(new NotFoundException('這張貼紙尚未啟用'));
    await expect(t.service.notifyOwner('tok', dto)).rejects.toThrow(/已用完/);
    expect(t.link?.usesLeft).toBe(0);
  });

  it('does not let a wrong code through when the link is already used up', async () => {
    const t = setup({ link: { usesLeft: 0 } });
    t.qr.scanByCode.mockRejectedValue(new NotFoundException('x'));
    await expect(t.service.notifyOwner('tok', dto)).rejects.toBeInstanceOf(GoneException);
  });

  it('rejects unknown, expired and used links without telling the owner', async () => {
    for (const [link, error] of [
      [null, NotFoundException],
      [{ expiresAt: new Date(Date.now() - 1000) }, GoneException],
      [{ usesLeft: 0 }, GoneException],
    ] as const) {
      const t = setup({ link });
      await expect(t.service.notifyOwner('tok', dto)).rejects.toBeInstanceOf(error);
      expect(t.notifications.create).not.toHaveBeenCalled();
    }
  });

  it('rate-limits one person across links, leaving the use unspent', async () => {
    const t = setup({ recentNotices: NOTICES_PER_HOUR });
    await expect(t.service.notifyOwner('tok', dto)).rejects.toBeInstanceOf(HttpException);
    expect(t.link?.usesLeft).toBe(3);
    expect(t.notifications.create).not.toHaveBeenCalled();
    expect(t.saved.some((s) => 'qrItemId' in s)).toBe(false);
  });

  it('keeps the notice when push fails', async () => {
    const t = setup({ pushEnabled: true });
    t.push.send.mockRejectedValue(new Error('fcm down'));
    await expect(t.service.notifyOwner('tok', dto)).resolves.toBeDefined();
    expect(t.notifications.create).toHaveBeenCalled();
  });
});
