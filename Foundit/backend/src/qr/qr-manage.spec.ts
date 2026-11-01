import { BadRequestException, ForbiddenException, GoneException, NotFoundException } from '@nestjs/common';
import { IsNull } from 'typeorm';
import { QrService } from './qr.service';
import { QrScanNotifier } from './qr-scan-notifier.service';
import { QrLandingController } from './qr-landing.controller';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { NotificationType } from '../common/entities/notification.entity';

const owner = { id: 'owner', status: 'active', fcmToken: null } as unknown as User;
const stranger = { id: 'stranger' } as User;
const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148';

function tag(extra: Partial<QrItem> = {}): QrItem {
  return { id: 'tag-1', userId: 'owner', name: '鑰匙', description: '', code: 'code-1234', qrCode: '', revokedAt: null, ...extra } as QrItem;
}

function serviceWith(row: QrItem | null) {
  const repo = {
    find: jest.fn().mockResolvedValue([]),
    findOne: jest.fn().mockResolvedValue(row),
    save: jest.fn(async (value: QrItem) => value),
  };
  const config = { get: (_: string, fallback?: string) => fallback };
  return { service: new QrService(repo as never, {} as never, config as never), repo };
}

describe('QrService tag management', () => {
  it('no longer lists tags the owner deleted', async () => {
    const { service, repo } = serviceWith(null);
    await service.findAllByUser('owner');
    expect(repo.find).toHaveBeenCalledWith(expect.objectContaining({
      where: { userId: 'owner', revokedAt: IsNull() },
    }));
  });

  it('renames a tag without changing its printed code', async () => {
    const { service } = serviceWith(tag());
    const updated = await service.update('tag-1', { name: '藍色鑰匙圈', description: '有一個小熊吊飾' }, owner);
    expect(updated).toMatchObject({ name: '藍色鑰匙圈', description: '有一個小熊吊飾', code: 'code-1234' });
  });

  it('refuses edits from other accounts, on deleted tags and with contact details', async () => {
    await expect(serviceWith(tag()).service.update('tag-1', { name: 'x' }, stranger))
      .rejects.toBeInstanceOf(ForbiddenException);
    await expect(serviceWith(tag({ revokedAt: new Date() })).service.update('tag-1', { name: 'x' }, owner))
      .rejects.toBeInstanceOf(NotFoundException);
    await expect(serviceWith(tag()).service.update('tag-1', { name: '鑰匙 0912345678' }, owner))
      .rejects.toBeInstanceOf(BadRequestException);
  });

  it('treats deleting an already deleted tag as done', async () => {
    const { service, repo } = serviceWith(tag({ revokedAt: new Date() }));
    await expect(service.remove('tag-1', owner)).resolves.toBeUndefined();
    expect(repo.save).not.toHaveBeenCalled();
  });
});

describe('QrService legacy self-generated tags', () => {
  function generator(env: Record<string, string> = {}) {
    const repo = { create: (v: object) => v, save: jest.fn(async (v: object) => v) };
    const config = { get: (key: string, fallback?: string) => env[key] ?? fallback };
    return new QrService(repo as never, {} as never, config as never);
  }

  it('keeps old App builds working: generated tags are bound to the creator at once', async () => {
    const created = await generator().generate({ name: '鑰匙' }, owner);
    expect(created).toMatchObject({ userId: 'owner', name: '鑰匙' });
    expect((created as { boundAt: Date }).boundAt).toBeInstanceOf(Date);
  });

  it('can be switched off once the bind-only App ships', async () => {
    await expect(generator({ QR_SELF_GENERATE: 'false' }).generate({ name: '鑰匙' }, owner))
      .rejects.toBeInstanceOf(GoneException);
  });

  it('rejects contact details in a bound sticker name too', async () => {
    const { service } = serviceWith(null);
    await expect(service.bind({ code: 'ABC234', name: '背包 0912345678' }, owner))
      .rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('QrScanNotifier', () => {
  function notifier() {
    const create = jest.fn().mockResolvedValue({});
    const push = { enabled: false, send: jest.fn() };
    return { notifier: new QrScanNotifier({ create } as never, push as never, {} as never), create };
  }

  it('tells the owner which tag was scanned without naming the finder', async () => {
    const { notifier: n, create } = notifier();
    n.scanned(tag(), owner, 'app');
    await new Promise((resolve) => setImmediate(resolve));
    expect(create).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'owner',
      type: NotificationType.QR_SCAN,
      content: expect.stringContaining('鑰匙'),
    }));
  });

  it('notifies once per tag within the quiet window', async () => {
    const { notifier: n, create } = notifier();
    n.scanned(tag(), owner, 'web');
    n.scanned(tag(), owner, 'app');
    n.scanned(tag({ id: 'tag-2' }), owner, 'web');
    await new Promise((resolve) => setImmediate(resolve));
    expect(create).toHaveBeenCalledTimes(2);
  });

  it('ignores link previews and crawlers', () => {
    expect(QrScanNotifier.isHumanBrowser(IPHONE)).toBe(true);
    expect(QrScanNotifier.isHumanBrowser('facebookexternalhit/1.1 Facebot Twitterbot/1.0')).toBe(false);
    expect(QrScanNotifier.isHumanBrowser('Mozilla/5.0 (compatible; Googlebot/2.1)')).toBe(false);
    expect(QrScanNotifier.isHumanBrowser(undefined)).toBe(false);
  });
});

describe('QR landing page', () => {
  const inspect = jest.fn().mockResolvedValue({ state: 'active', qrItem: { ...tag({ name: '<b>包包</b>' }), user: owner } });
  const scanByCode = inspect;

  it('offers to open the tag in the app and notifies the owner for real phone scans', async () => {
    const scanned = jest.fn();
    const page = new QrLandingController({ inspect: scanByCode } as never, { scanned } as never);
    const html = await page.page('code-1234', { method: 'GET', userAgent: IPHONE });
    expect(html).toContain('href="foundit://qr/code-1234"');
    expect(html).toContain('&lt;b&gt;包包&lt;/b&gt;');
    expect(scanned).toHaveBeenCalledWith(expect.anything(), owner, 'web');
  });

  it('explains unbound stickers and offers the LINE route on bound ones', async () => {
    const unbound = new QrLandingController({ inspect: async () => ({ state: 'unbound', qrItem: tag() }) } as never);
    expect(await unbound.page('ABC234')).toContain('這張貼紙尚未啟用');
    const page = new QrLandingController({ inspect } as never);
    expect(await page.page('code-1234')).toContain('line.me');
  });

  it('does not notify for HEAD requests or bots', async () => {
    const scanned = jest.fn();
    const page = new QrLandingController({ inspect: scanByCode } as never, { scanned } as never);
    await page.page('code-1234', { method: 'HEAD', userAgent: IPHONE });
    await page.page('code-1234', { method: 'GET', userAgent: 'Slackbot-LinkExpanding 1.0' });
    expect(scanned).not.toHaveBeenCalled();
  });

  it('only shows a download button for an https link', async () => {
    const config = (url: string) => ({ get: () => url });
    const withLink = new QrLandingController({ inspect: scanByCode } as never, undefined, config('https://testflight.apple.com/join/abc') as never);
    expect(await withLink.page('code-1234')).toContain('https://testflight.apple.com/join/abc');
    const unsafe = new QrLandingController({ inspect: scanByCode } as never, undefined, config('javascript:alert(1)') as never);
    expect(await unsafe.page('code-1234')).not.toContain('javascript:');
  });
});
