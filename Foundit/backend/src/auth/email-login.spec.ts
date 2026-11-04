import { ConflictException, ForbiddenException, HttpException, UnauthorizedException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { WebAuthController } from './web-auth.controller';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { OtpService } from './otp.service';
import { ChatsGateway } from '../chats/chats.gateway';
import { emailAccountKey, hashPassword, normalizeEmail, verifyPassword } from './password';

describe('passwords', () => {
  it('hashes with a fresh salt and verifies only the right password', async () => {
    const a = await hashPassword('correct horse battery');
    const b = await hashPassword('correct horse battery');
    expect(a).toMatch(/^scrypt\$16384\$8\$1\$[A-Za-z0-9+/=]+\$[A-Za-z0-9+/=]+$/);
    expect(a).not.toBe(b);
    expect(await verifyPassword('correct horse battery', a)).toBe(true);
    expect(await verifyPassword('correct horse batterz', a)).toBe(false);
    expect(await verifyPassword('anything', null)).toBe(false);
    expect(await verifyPassword('anything', 'not-a-hash')).toBe(false);
  });

  it('keys email accounts apart from Google accounts and ignores case and spaces', () => {
    expect(normalizeEmail('  Someone@Example.COM ')).toBe('someone@example.com');
    expect(emailAccountKey('Someone@Example.com')).toBe(emailAccountKey('someone@example.com '));
    expect(emailAccountKey('someone@example.com')).toMatch(/^e:[0-9a-f]{64}$/);
    expect(emailAccountKey('someone@example.com')).not.toContain('someone');
  });
});

describe('AuthService email accounts', () => {
  type Stored = Partial<User> & { id: string };
  let rows: Stored[];
  let points: { findOne: jest.Mock; save: jest.Mock; create: jest.Mock };
  let service: AuthService;

  beforeEach(() => {
    rows = [];
    const users = {
      findOne: jest.fn(async ({ where }: { where: Partial<User> }) => {
        const row = rows.find((r) => Object.entries(where).every(([k, v]) => (r as Record<string, unknown>)[k] === v));
        if (!row) return null;
        const { passwordHash: _hidden, ...visible } = row; // select: false
        return { ...visible };
      }),
      create: jest.fn((u: Partial<User>) => ({ ...u })),
      save: jest.fn(async (u: Stored) => {
        if (!u.id) {
          if (rows.some((r) => r.phone === u.phone)) throw Object.assign(new Error('duplicate'), { code: '23505' });
          u = { ...u, id: `user-${rows.length + 1}` };
          rows.push(u);
        }
        return u;
      }),
      createQueryBuilder: jest.fn(() => {
        let key = '';
        const qb = {
          addSelect: () => qb,
          where: (_: string, params: { key: string }) => {
            key = params.key;
            return qb;
          },
          getOne: async () => {
            const row = rows.find((r) => r.phone === key);
            return row ? { ...row } : null;
          },
        };
        return qb;
      }),
    };
    points = { findOne: jest.fn(), save: jest.fn(), create: jest.fn((v) => v) };
    const config = { get: (key: string) => (key === 'ADMIN_EMAILS' ? 'boss@example.com' : undefined) } as unknown as ConfigService;
    service = new AuthService(
      users as unknown as Repository<User>,
      points as unknown as Repository<UserPoints>,
      {} as OtpService,
      { sign: jest.fn((p: { sub: string }) => `token-for-${p.sub}`) } as unknown as JwtService,
      config,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
    );
  });

  it('creates an unverified, plain account keyed apart from Google, storing only a hash', async () => {
    const { token, user } = await service.emailRegister({ email: 'Boss@Example.com', password: 'long enough pass', name: '小明' });
    expect(token).toBe(`token-for-${user.id}`);
    const row = rows[0];
    expect(row.phone).toBe(emailAccountKey('boss@example.com'));
    expect(row.googleSub).toBeUndefined();
    expect(row.email).toBe('boss@example.com');
    expect(row.verifiedEmail).toBe(''); // never staff or admin, never mailed
    expect(row.isVerified).toBe(false);
    expect(row.role).toBe('user'); // ADMIN_EMAILS lists this address, but it is not proven
    expect(row.passwordHash).toMatch(/^scrypt\$/);
    expect(row.passwordHash).not.toContain('long enough pass');
    expect(row.name).toBe('小明');
    expect(points.save).toHaveBeenCalled();
  });

  it('does not use the email as the public name', async () => {
    await service.emailRegister({ email: 'private.person@example.com', password: 'long enough pass' });
    expect(rows[0].name).toBe('Email 用戶');
  });

  it('refuses a second sign-up for the same email, whatever its case', async () => {
    await service.emailRegister({ email: 'a@example.com', password: 'long enough pass' });
    await expect(service.emailRegister({ email: 'A@EXAMPLE.com', password: 'another password' })).rejects.toBeInstanceOf(ConflictException);
  });

  it('signs in with the right password only, with one message for every failure', async () => {
    await service.emailRegister({ email: 'a@example.com', password: 'long enough pass' });
    const ok = await service.emailLogin({ email: ' A@example.com', password: 'long enough pass' });
    expect(ok.user.id).toBe(rows[0].id);
    expect(ok.user).not.toHaveProperty('passwordHash');
    for (const attempt of [{ email: 'a@example.com', password: 'wrong password' }, { email: 'nobody@example.com', password: 'long enough pass' }]) {
      await expect(service.emailLogin(attempt)).rejects.toThrow('Email 或密碼不正確');
    }
  });

  it('stops an account after 10 wrong passwords in 15 minutes, even with the right one', async () => {
    await service.emailRegister({ email: 'a@example.com', password: 'long enough pass' });
    for (let i = 0; i < 10; i++) {
      await expect(service.emailLogin({ email: 'a@example.com', password: `wrong ${i} password` })).rejects.toBeInstanceOf(UnauthorizedException);
    }
    await expect(service.emailLogin({ email: 'a@example.com', password: 'long enough pass' })).rejects.toBeInstanceOf(HttpException);
    await expect(service.emailLogin({ email: 'a@example.com', password: 'long enough pass' })).rejects.toThrow('嘗試太多次');
  });

  it('refuses suspended and deleted accounts', async () => {
    await service.emailRegister({ email: 'a@example.com', password: 'long enough pass' });
    rows[0].status = 'suspended';
    await expect(service.emailLogin({ email: 'a@example.com', password: 'long enough pass' })).rejects.toThrow('這個帳號無法登入');
  });
});

describe('Web email sign-in boundary', () => {
  const prior = process.env.CORS_ORIGINS;
  afterEach(() => {
    if (prior === undefined) delete process.env.CORS_ORIGINS;
    else process.env.CORS_ORIGINS = prior;
  });

  it('refuses an unapproved origin before touching the account', async () => {
    process.env.CORS_ORIGINS = 'https://app.foundit.tw';
    const auth = { emailLogin: jest.fn(), emailRegister: jest.fn() };
    const controller = new WebAuthController(auth as never, {} as never);
    const request = { headers: { origin: 'https://untrusted.example' } } as never;
    await expect(controller.emailLogin({ email: 'a@example.com', password: 'long enough pass' }, request, {} as never)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(controller.emailRegister({ email: 'a@example.com', password: 'long enough pass' }, request, {} as never)).rejects.toBeInstanceOf(ForbiddenException);
    expect(auth.emailLogin).not.toHaveBeenCalled();
    expect(auth.emailRegister).not.toHaveBeenCalled();
  });

  it('sets the same session cookie as Google sign-in and registers the campus member', async () => {
    process.env.CORS_ORIGINS = 'https://app.foundit.tw';
    const user = { id: 'u1', name: 'Email 用戶', status: 'active', email: 'a@example.com' };
    const auth = { emailLogin: jest.fn().mockResolvedValue({ token: 'tok', user }), tokenExpiry: () => Date.now() + 60000 };
    const db = { query: jest.fn().mockResolvedValue([]) };
    const response = { set: jest.fn().mockReturnThis(), cookie: jest.fn().mockReturnThis() };
    const body = await new WebAuthController(auth as never, db as never).emailLogin(
      { email: 'a@example.com', password: 'long enough pass' },
      { headers: { origin: 'https://app.foundit.tw' } } as never,
      response as never,
    );
    expect(body).toMatchObject({ success: true, token: 'tok', user: { id: 'u1', email: 'a@example.com' } });
    expect(response.cookie.mock.calls[0][0]).toBe('__Secure-foundit-web');
    expect(response.cookie.mock.calls[0][2]).toMatchObject({ httpOnly: true, secure: true, sameSite: 'lax', path: '/api/v1/auth' });
    expect(db.query.mock.calls[0][0]).toMatch(/INSERT INTO campus\.members/);
  });
});
