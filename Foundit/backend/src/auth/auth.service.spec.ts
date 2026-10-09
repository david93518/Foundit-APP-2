import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { AuthService } from './auth.service';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { OtpService } from './otp.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ChatsGateway } from '../chats/chats.gateway';
import { verifyGoogleIdToken } from './google-id-token';

jest.mock('./google-id-token', () => ({
  verifyGoogleIdToken: jest.fn(),
}));

describe('AuthService oauth boundary', () => {
  const verify = verifyGoogleIdToken as jest.MockedFunction<typeof verifyGoogleIdToken>;
  let users: { findOne: jest.Mock; save: jest.Mock; create: jest.Mock };
  let service: AuthService;

  beforeEach(() => {
    verify.mockReset();
    users = {
      findOne: jest.fn(),
      save: jest.fn(async (user) => user),
      create: jest.fn((user) => user),
    };
    const config = {
      get: (key: string) => (key === 'GOOGLE_WEB_CLIENT_ID' ? 'client.apps.googleusercontent.com' : undefined),
    } as ConfigService;
    service = new AuthService(
      users as unknown as Repository<User>,
      { findOne: jest.fn(), save: jest.fn(), create: jest.fn() } as unknown as Repository<UserPoints>,
      {} as OtpService,
      { sign: jest.fn(() => 'token') } as unknown as JwtService,
      config,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
    );
  });

  it('does not create an account for an unknown provider', async () => {
    await expect(service.oauthLogin('line', { token: 'x', provider: 'line' })).rejects.toBeInstanceOf(BadRequestException);
    expect(users.findOne).not.toHaveBeenCalled();
    expect(verify).not.toHaveBeenCalled();
  });

  it('does not decode a failed Google token', async () => {
    verify.mockRejectedValue(new Error('bad signature'));
    await expect(service.oauthLogin('google', { token: 'forged', provider: 'google' })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(users.save).not.toHaveBeenCalled();
  });

  it('refuses Google login when the audience is not configured', async () => {
    const config = { get: () => undefined } as unknown as ConfigService;
    const unconfigured = new AuthService(
      users as unknown as Repository<User>,
      {} as Repository<UserPoints>,
      {} as OtpService,
      { sign: jest.fn() } as unknown as JwtService,
      config,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
    );
    await expect(unconfigured.oauthLogin('google', { token: 'x', provider: 'google' })).rejects.toBeInstanceOf(BadRequestException);
    expect(verify).not.toHaveBeenCalled();
  });

  it('creates identity only from verified Google claims, ignoring supplied profile data', async () => {
    verify.mockResolvedValue({ sub: 'subject-1', email: 'verified@example.com', name: 'Verified', picture: 'https://lh3.googleusercontent.com/a/photo', issuedAt: Math.floor(Date.now() / 1000) });
    users.findOne.mockResolvedValue(null);
    await service.oauthLogin('google', { token: 'valid', provider: 'google', name: 'forged', avatarUrl: 'https://evil.example/photo' });
    expect(users.create).toHaveBeenCalledWith(expect.objectContaining({
      googleSub: 'subject-1', email: 'verified@example.com', name: 'Verified', avatarUrl: 'https://lh3.googleusercontent.com/a/photo', role: 'user',
    }));
  });

  it('does not admit a suspended verified Google user', async () => {
    verify.mockResolvedValue({ sub: 'subject-1', email: 'verified@example.com', name: '', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue({ status: 'suspended' });
    await expect(service.oauthLogin('google', { token: 'valid', provider: 'google' })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(users.save).not.toHaveBeenCalled();
  });
});

describe('AuthService admin promotion by email', () => {
  const verify = verifyGoogleIdToken as jest.MockedFunction<typeof verifyGoogleIdToken>;

  function build(adminEmails: string) {
    const users = {
      findOne: jest.fn(),
      save: jest.fn(async (user) => user),
      create: jest.fn((user) => user),
    };
    const config = {
      get: (key: string) => {
        if (key === 'GOOGLE_WEB_CLIENT_ID') return 'client.apps.googleusercontent.com';
        if (key === 'ADMIN_EMAILS') return adminEmails;
        return undefined;
      },
    } as ConfigService;
    const service = new AuthService(
      users as unknown as Repository<User>,
      { findOne: jest.fn(), save: jest.fn(), create: jest.fn() } as unknown as Repository<UserPoints>,
      {} as OtpService,
      { sign: jest.fn(() => 'token') } as unknown as JwtService,
      config,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
    );
    return { users, service };
  }

  beforeEach(() => verify.mockReset());

  it('does not grant a role even for a listed verified email on first login', async () => {
    const { users, service } = build(' Owner@Example.com ,other@example.com');
    verify.mockResolvedValue({ sub: 's1', email: 'owner@example.com', name: 'Owner', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue(null);
    const { user } = await service.oauthLogin('google', { token: 'valid', provider: 'google' });
    expect(user.role).toBe('user');
    expect(users.save).toHaveBeenLastCalledWith(expect.objectContaining({ role: 'user' }));
  });

  it('preserves an operator-provisioned administrator', async () => {
    const { users, service } = build('owner@example.com');
    verify.mockResolvedValue({ sub: 's1', email: 'owner@example.com', name: 'Owner', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue({ id: 'u1', status: 'active', role: 'admin', name: 'Owner', email: '', googleSub: 's1' });
    const { user } = await service.oauthLogin('google', { token: 'valid', provider: 'google' });
    expect(user.role).toBe('admin');
  });

  it('leaves unlisted Google accounts as plain users', async () => {
    const { users, service } = build('owner@example.com');
    verify.mockResolvedValue({ sub: 's2', email: 'someone@example.com', name: 'Someone', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue(null);
    const { user } = await service.oauthLogin('google', { token: 'valid', provider: 'google' });
    expect(user.role).toBe('user');
  });

  it('never promotes an account whose email is empty even when the list has blanks', async () => {
    const { users, service } = build(' , ,');
    verify.mockResolvedValue({ sub: 's3', email: '', name: 'Blank', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue(null);
    const { user } = await service.oauthLogin('google', { token: 'valid', provider: 'google' });
    expect(user.role).toBe('user');
  });
});

describe('AuthService admin promotion', () => {
  const verify = verifyGoogleIdToken as jest.MockedFunction<typeof verifyGoogleIdToken>;
  const settings: Record<string, string> = {
    GOOGLE_WEB_CLIENT_ID: 'client.apps.googleusercontent.com',
    ADMIN_EMAILS: 'boss@example.com',
    ADMIN_PHONES: '0911111111',
  };
  function build(existing: Partial<User>) {
    const users = {
      findOne: jest.fn(async () => ({ id: 'u1', role: 'user', status: 'active', tokenVersion: 0, ...existing })),
      save: jest.fn(async (user) => user),
      create: jest.fn((user) => user),
    };
    const service = new AuthService(
      users as unknown as Repository<User>,
      { findOne: jest.fn(async () => ({})), save: jest.fn(), create: jest.fn() } as unknown as Repository<UserPoints>,
      { verify: jest.fn(() => true) } as unknown as OtpService,
      { sign: jest.fn(() => 'token') } as unknown as JwtService,
      { get: (key: string) => settings[key] } as ConfigService,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
    );
    return service;
  }

  it('ignores a self-edited profile email when logging in by phone', async () => {
    const service = build({ phone: '0922222222', email: 'boss@example.com' });
    const { user } = await service.verifyOtp({ phone: '0922222222', otp: '123456' });
    expect(user.role).toBe('user');
  });

  it('does not grant a role via the phone allow-list', async () => {
    const service = build({ phone: '0911111111' });
    expect((await service.verifyOtp({ phone: '0911111111', otp: '123456' })).user.role).toBe('user');
  });

  it('does not grant a role through either a stored or verified email', async () => {
    verify.mockResolvedValue({ sub: 's1', email: 'someone@example.com', name: 'n', picture: '', issuedAt: 0 });
    const notAdmin = build({ googleSub: 's1', email: 'boss@example.com' });
    expect((await notAdmin.oauthLogin('google', { token: 't', provider: 'google' })).user.role).toBe('user');
    verify.mockResolvedValue({ sub: 's2', email: 'Boss@Example.com', name: 'n', picture: '', issuedAt: 0 });
    const admin = build({ googleSub: 's2', email: '' });
    expect((await admin.oauthLogin('google', { token: 't', provider: 'google' })).user.role).toBe('user');
  });
});

describe('AuthService admin list is the source of truth', () => {
  const verify = verifyGoogleIdToken as jest.MockedFunction<typeof verifyGoogleIdToken>;
  function build(settings: Record<string, string>, existing: Partial<User>) {
    const users = {
      findOne: jest.fn(async () => ({ id: 'u1', role: 'admin', status: 'active', tokenVersion: 0, ...existing })),
      save: jest.fn(async (user) => user),
      create: jest.fn((user) => user),
    };
    const actions = { create: jest.fn((row) => row), save: jest.fn(async (row) => row) };
    const service = new AuthService(
      users as unknown as Repository<User>,
      { findOne: jest.fn(async () => ({})), save: jest.fn(), create: jest.fn() } as unknown as Repository<UserPoints>,
      {} as OtpService,
      { sign: jest.fn(() => 'token') } as unknown as JwtService,
      { get: (key: string) => ({ GOOGLE_WEB_CLIENT_ID: 'client.apps.googleusercontent.com', ...settings })[key] } as ConfigService,
      { disconnectUser: jest.fn() } as unknown as ChatsGateway,
      actions as never,
    );
    return { service, actions };
  }

  it('denies an unlisted administrator without attempting a role change', async () => {
    verify.mockResolvedValue({ sub: 's9', email: 'former@example.com', name: 'n', picture: '', issuedAt: 0 });
    const { service, actions } = build({ ADMIN_EMAILS: 'boss@example.com' }, { googleSub: 's9' });
    await expect(service.oauthLogin('google', { token: 't', provider: 'google' })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(actions.save).not.toHaveBeenCalled();
  });

  it('leaves manually assigned admins alone when no admin list is configured', async () => {
    verify.mockResolvedValue({ sub: 's9', email: 'former@example.com', name: 'n', picture: '', issuedAt: 0 });
    const { service, actions } = build({}, { googleSub: 's9' });
    expect((await service.oauthLogin('google', { token: 't', provider: 'google' })).user.role).toBe('admin');
    expect(actions.save).not.toHaveBeenCalled();
  });

  it('replaces an impersonating Google display name with a neutral one', async () => {
    verify.mockResolvedValue({ sub: 'new', email: 'x@example.com', name: 'FOUND !T 官方客服', picture: 'https://evil.example/p.png', issuedAt: 0 });
    const { service } = build({}, {});
    (service as unknown as { userRepo: { findOne: jest.Mock } }).userRepo.findOne.mockResolvedValue(null);
    const { user } = await service.oauthLogin('google', { token: 't', provider: 'google' });
    expect(user.name).toBe('Google 用戶');
    expect(user.avatarUrl).toBe('');
  });
});
