import { WebAuthController } from './web-auth.controller';
import { AuthService } from './auth.service';
import { JwtService } from '@nestjs/jwt';
import { ForbiddenException, UnauthorizedException } from '@nestjs/common';

describe('Web session boundary', () => {
  const prior = process.env.CORS_ORIGINS;
  afterEach(() => {
    if (prior === undefined) delete process.env.CORS_ORIGINS;
    else process.env.CORS_ORIGINS = prior;
  });
  it('refuses login/session reads from an unapproved origin before reading credentials', async () => {
    process.env.CORS_ORIGINS = 'https://app.foundit.tw';
    const auth = { oauthLogin: jest.fn(), webSession: jest.fn() };
    const controller = new WebAuthController(auth as any, {} as any);
    const request = {
      headers: {
        origin: 'https://untrusted.example',
        cookie: '__Secure-foundit-web=secret',
      },
    } as any;
    await expect(
      controller.login(
        { provider: 'google', token: 'test' },
        request,
        {} as any,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(controller.session(request, {} as any)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(auth.oauthLogin).not.toHaveBeenCalled();
    expect(auth.webSession).not.toHaveBeenCalled();
  });
  it('uses a host-only Secure HttpOnly cookie restricted to auth routes and never caches the token response', async () => {
    process.env.CORS_ORIGINS = 'https://app.foundit.tw';
    const user = { id: 'u', name: 'name', status: 'active' };
    const auth = {
      oauthLogin: jest.fn().mockResolvedValue({ token: 'test-token', user }),
      tokenExpiry: () => Date.now() + 60000,
    };
    const db = { query: jest.fn().mockResolvedValue([]) };
    const response: any = {
      set: jest.fn().mockReturnThis(),
      cookie: jest.fn().mockReturnThis(),
    };
    await new WebAuthController(auth as any, db as any).login(
      { provider: 'google', token: 'verified-by-auth-service' },
      { headers: { origin: 'https://app.foundit.tw' } } as any,
      response,
    );
    const options = response.cookie.mock.calls[0][2];
    expect(auth.oauthLogin).toHaveBeenCalledWith('google', expect.any(Object), true);
    expect(options).toMatchObject({
      secure: true,
      httpOnly: true,
      sameSite: 'lax',
      path: '/api/v1/auth',
    });
    expect(options.domain).toBeUndefined();
    expect(response.set).toHaveBeenCalledWith('Cache-Control', 'no-store');
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('campus.members'),
      ['u'],
    );
  });
  it('rechecks token version and account state on every browser bootstrap', async () => {
    const jwt = new JwtService({
      secret: 'test-only-jwt-secret',
      signOptions: { expiresIn: '1h', algorithm: 'HS256' },
    });
    const user = {
      id: '00000000-0000-4000-8000-000000000001',
      status: 'active',
      tokenVersion: 1,
    };
    const repo = { findOne: jest.fn().mockResolvedValue(user) };
    const service = new AuthService(
      repo as any,
      {} as any,
      {} as any,
      jwt,
      {} as any,
      {} as any,
    );
    await expect(
      service.webSession(jwt.sign({ sub: user.id, tv: 0 })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(
      service.webSession(jwt.sign({ sub: user.id, tv: 1 })),
    ).resolves.toBe(user);
    user.status = 'suspended';
    await expect(
      service.webSession(jwt.sign({ sub: user.id, tv: 1 })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(service.webSession('invalid')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
