import { DatabaseSecurityService } from './database-security.service';

describe('production DB privilege checks', () => {
  it.each([
    ['superuser or owner', true, Buffer.from('app\0')],
    ['missing trigger', false, null],
    ['trigger protecting a different role', false, Buffer.from('other\0')],
  ])('refuses startup with %s', async (_, unsafe, args) => {
    const db = { query: jest.fn().mockResolvedValueOnce([{ name: 'app', unsafe }])
      .mockResolvedValueOnce(args ? [{ tgargs: args }] : []) };
    const service = new DatabaseSecurityService(db as never, { get: () => 'production' } as never);
    await expect(service.onApplicationBootstrap()).rejects.toThrow('資料庫權限未完成隔離');
  });
  it('accepts the protected non-owner role', async () => {
    const db = { query: jest.fn().mockResolvedValueOnce([{ name: 'app', unsafe: false }])
      .mockResolvedValueOnce([{ tgargs: Buffer.from('app\0') }]) };
    const service = new DatabaseSecurityService(db as never, { get: () => 'production' } as never);
    await expect(service.onApplicationBootstrap()).resolves.toBeUndefined();
  });
});
