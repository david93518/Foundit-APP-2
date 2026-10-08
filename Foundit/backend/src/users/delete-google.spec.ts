import { ConfigService } from '@nestjs/config';
import { UsersService } from './users.service';
import { verifyGoogleIdToken } from '../auth/google-id-token';

jest.mock('../auth/google-id-token', () => ({ verifyGoogleIdToken: jest.fn() }));

describe('Google deletion reauthentication', () => {
  const verify = verifyGoogleIdToken as jest.Mock;
  let service: UsersService;
  let erase: jest.SpyInstance;
  beforeEach(() => {
    verify.mockReset();
    service = new UsersService(
      { findOne: jest.fn(async () => ({ id: 'account', googleSub: 'subject', status: 'active' })) } as any,
      {} as any, {} as any, {} as any, {} as any, {} as any, {} as any,
      { get: () => 'client.apps.googleusercontent.com' } as unknown as ConfigService,
    );
    erase = jest.spyOn(service as any, 'eraseAccount').mockResolvedValue(undefined);
  });
  it.each([
    ['other Google account', 'someone-else', 0],
    ['stale confirmation', 'subject', 301],
    ['invalid issuance', 'subject', Number.NaN],
  ])('rejects %s without deleting data', async (_, sub, age) => {
    verify.mockResolvedValue({ sub, issuedAt: Math.floor(Date.now() / 1000) - Number(age) });
    await expect(service.deleteGoogleAccount('account', 'token')).rejects.toThrow();
    expect(erase).not.toHaveBeenCalled();
  });
  it('accepts recent confirmation by the same Google account', async () => {
    verify.mockResolvedValue({ sub: 'subject', issuedAt: Math.floor(Date.now() / 1000) });
    await service.deleteGoogleAccount('account', 'token');
    expect(erase).toHaveBeenCalledWith(expect.objectContaining({ id: 'account' }));
  });
});
