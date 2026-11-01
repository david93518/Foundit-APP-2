import { ConflictException, ForbiddenException, GoneException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { QrService, MAX_BOUND_PER_USER } from './qr.service';
import { QrItem } from '../common/entities/qr-item.entity';
import { QrBatch } from '../common/entities/qr-batch.entity';
import { User } from '../common/entities/user.entity';

const user = { id: 'user-1', status: 'active' } as User;
const admin = { id: 'admin-1', status: 'active', role: 'admin' } as User;

function item(over: Partial<QrItem> = {}): QrItem {
  return {
    id: 'qr-1',
    code: 'K7M2P9',
    qrCode: 'https://app.foundit.tw/qr/K7M2P9',
    userId: null,
    user: null,
    name: '',
    description: '',
    boundAt: null,
    disabledAt: null,
    revokedAt: null,
    batchId: 'batch-1',
    ...over,
  } as QrItem;
}

function setup(rows: Partial<{ found: QrItem | null; bound: number; affected: number }> = {}) {
  const inserted: unknown[][] = [];
  const qb = {
    insert: jest.fn().mockReturnThis(),
    into: jest.fn().mockReturnThis(),
    values: jest.fn((v: unknown[]) => {
      inserted.push(v);
      return qb;
    }),
    execute: jest.fn().mockResolvedValue({}),
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    getOne: jest.fn().mockResolvedValue(rows.found ?? null),
  };
  const qrRepo = {
    createQueryBuilder: jest.fn(() => qb),
    count: jest.fn().mockResolvedValue(rows.bound ?? 0),
    update: jest.fn().mockResolvedValue({ affected: rows.affected ?? 0 }),
    findOne: jest.fn().mockResolvedValue(rows.found ?? null),
    find: jest.fn().mockResolvedValue([]),
    save: jest.fn(async (v: QrItem) => v),
  };
  const batchRepo = {
    create: jest.fn((v: object) => ({ id: 'batch-1', ...v })),
    save: jest.fn(async (v: object) => v),
  };
  const config = { get: (_k: string, d?: string) => d } as unknown as ConfigService;
  const service = new QrService(
    qrRepo as unknown as Repository<QrItem>,
    batchRepo as unknown as Repository<QrBatch>,
    config,
  );
  return { service, qrRepo, batchRepo, inserted, qb };
}

describe('QrService.bind', () => {
  it('binds an unbound sticker with a single conditional UPDATE', async () => {
    const t = setup({ affected: 1, found: item({ userId: user.id, name: '後背包' }) });
    const bound = await t.service.bind({ code: 'k7m2p9', name: ' 後背包 ' }, user);
    expect(bound.name).toBe('後背包');
    const [where, set] = t.qrRepo.update.mock.calls[0];
    expect(where.code).toBe('K7M2P9');
    for (const key of ['userId', 'disabledAt', 'revokedAt']) expect(where[key]).toBeDefined();
    expect(set).toMatchObject({ userId: user.id, name: '後背包', description: '' });
    expect(set.boundAt).toBeInstanceOf(Date);
  });

  it('answers 409 when the sticker already has an owner', async () => {
    const t = setup({ affected: 0, found: item({ userId: 'someone', boundAt: new Date() }) });
    await expect(t.service.bind({ code: 'K7M2P9', name: 'x' }, user)).rejects.toBeInstanceOf(ConflictException);
  });

  it('answers 404 for a code that does not exist or is malformed', async () => {
    const missing = setup({ affected: 0, found: null });
    await expect(missing.service.bind({ code: 'K7M2P9', name: 'x' }, user)).rejects.toBeInstanceOf(NotFoundException);
    const malformed = setup();
    await expect(malformed.service.bind({ code: '../x', name: 'x' }, user)).rejects.toBeInstanceOf(NotFoundException);
    expect(malformed.qrRepo.update).not.toHaveBeenCalled();
  });

  it('answers 410 for a disabled sticker', async () => {
    const t = setup({ affected: 0, found: item({ disabledAt: new Date() }) });
    await expect(t.service.bind({ code: 'K7M2P9', name: 'x' }, user)).rejects.toBeInstanceOf(GoneException);
  });

  it('stops at the per-user limit before touching the sticker', async () => {
    const t = setup({ bound: MAX_BOUND_PER_USER });
    await expect(t.service.bind({ code: 'K7M2P9', name: 'x' }, user)).rejects.toBeInstanceOf(ForbiddenException);
    expect(t.qrRepo.update).not.toHaveBeenCalled();
  });
});

describe('QrService.scanByCode', () => {
  const owner = { id: 'user-1', status: 'active' } as User;

  it('returns a bound sticker with its owner', async () => {
    const found = item({ userId: owner.id, user: owner, boundAt: new Date(), name: '後背包' });
    const { qrItem, owner: o } = await setup({ found }).service.scanByCode('K7M2P9');
    expect(qrItem.name).toBe('後背包');
    expect(o).toBe(owner);
  });

  it('refuses a sticker nobody has bound yet, with its own message', async () => {
    const t = setup({ found: item() });
    await expect(t.service.scanByCode('K7M2P9')).rejects.toThrow('尚未啟用');
  });

  it.each([
    ['disabled', { disabledAt: new Date(), userId: owner.id, user: owner, boundAt: new Date() }],
    ['revoked', { revokedAt: new Date(), userId: owner.id, user: owner, boundAt: new Date() }],
    ['deleted owner', { userId: owner.id, user: { ...owner, status: 'deleted' } as User, boundAt: new Date() }],
  ])('refuses a %s sticker', async (_name, over) => {
    await expect(setup({ found: item(over as Partial<QrItem>) }).service.scanByCode('K7M2P9')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('refuses malformed codes without querying', async () => {
    const t = setup();
    await expect(t.service.scanByCode("x'; --")).rejects.toBeInstanceOf(NotFoundException);
    expect(t.qb.getOne).not.toHaveBeenCalled();
  });
});

describe('QrService.createBatch', () => {
  it('creates unique unbound stickers with public URLs', async () => {
    const t = setup();
    const { batch, codes } = await t.service.createBatch({ label: '總圖', place: '一樓', count: 250 }, admin);
    expect(batch).toMatchObject({ label: '總圖', place: '一樓', count: 250, createdBy: admin.id });
    expect(new Set(codes).size).toBe(250);
    const rows = t.inserted.flat() as Array<{ code: string; qrCode: string; batchId: string; name: string }>;
    expect(rows).toHaveLength(250);
    expect(t.inserted.length).toBe(3);
    expect(rows[0].qrCode).toBe(`http://localhost:3000/qr/${rows[0].code}`);
    expect(rows.every((r) => r.batchId === 'batch-1' && r.name === '')).toBe(true);
  });

  it('replaces codes that already exist in the database', async () => {
    const t = setup();
    let first = true;
    t.qrRepo.find.mockImplementation(async (opts: { where: { code: { _value: string[] } } }) => {
      const values = opts.where.code._value;
      if (first) {
        first = false;
        return [{ code: values[0] }];
      }
      return [];
    });
    const { codes } = await t.service.createBatch({ label: 'x', count: 5 }, admin);
    expect(codes).toHaveLength(5);
    expect(t.qrRepo.find).toHaveBeenCalledTimes(2);
  });
});

describe('QrService.disable and remove', () => {
  it('disables a whole batch, counting what changed', async () => {
    const t = setup({ affected: 12 });
    expect(await t.service.disable({ batchId: 'batch-1' })).toBe(12);
  });

  it('404s when a single sticker is missing or already disabled', async () => {
    await expect(setup({ affected: 0 }).service.disable({ code: 'K7M2P9' })).rejects.toBeInstanceOf(NotFoundException);
  });

  it('lets only the owner revoke', async () => {
    const mine = setup({ found: item({ userId: user.id, boundAt: new Date() }) });
    await mine.service.remove('qr-1', user);
    expect(mine.qrRepo.save.mock.calls[0][0].revokedAt).toBeInstanceOf(Date);
    const other = setup({ found: item({ userId: 'x', boundAt: new Date() }) });
    await expect(other.service.remove('qr-1', user)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
