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
    verify.mockResolvedValue({ sub: 'subject-1', email: 'verified@example.com', name: 'Verified', picture: 'https://example.com/photo', issuedAt: Math.floor(Date.now() / 1000) });
    users.findOne.mockResolvedValue(null);
    await service.oauthLogin('google', { token: 'valid', provider: 'google', name: 'forged', avatarUrl: 'https://evil.example/photo' });
    expect(users.create).toHaveBeenCalledWith(expect.objectContaining({
      googleSub: 'subject-1', email: 'verified@example.com', name: 'Verified', avatarUrl: 'https://example.com/photo', role: 'user',
    }));
  });

  it('does not admit a suspended verified Google user', async () => {
    verify.mockResolvedValue({ sub: 'subject-1', email: 'verified@example.com', name: '', picture: '', issuedAt: 1 });
    users.findOne.mockResolvedValue({ status: 'suspended' });
    await expect(service.oauthLogin('google', { token: 'valid', provider: 'google' })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(users.save).not.toHaveBeenCalled();
  });
});
