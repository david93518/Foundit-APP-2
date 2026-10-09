import { ConfigService } from '@nestjs/config';
import { UnauthorizedException } from '@nestjs/common';
import { scryptSync } from 'node:crypto';
import { verifyInvitedCredentials } from './invited-credentials';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { User } from '../common/entities/user.entity';

describe('Explicitly provisioned invited account', () => {
  const id = '9bc0a1a3-1245-4ce7-8ad8-32fc382df033';
  const password = 'Unit-test-password-only-123';
  const salt = Buffer.alloc(16, 7);
  const settings = {
    INVITED_LOGIN_USERNAME: 'test-invite', INVITED_LOGIN_USER_ID: id,
    INVITED_LOGIN_EXPIRES_AT: '2099-01-01T00:00:00Z',
    INVITED_LOGIN_PASSWORD_HASH: `scrypt:${salt.toString('hex')}:${scryptSync(password, salt, 64).toString('hex')}`,
  };
  const config = (patch = {}) => ({get: (key: string) => ({...settings, ...patch})[key]}) as ConfigService;
  const account = () => ({id, phone: 'invited:test-invite', role: 'user', status: 'active', googleSub: null, tokenVersion: 4});

  it('verifies the entire password and exact username', async () => {
    await expect(verifyInvitedCredentials(config(), 'test-invite', password)).resolves.toBe(id);
    await expect(verifyInvitedCredentials(config(), 'another-user', password)).resolves.toBeNull();
    await expect(verifyInvitedCredentials(config(), 'test-invite', password + 'x')).resolves.toBeNull();
  });

  it.each([
    { INVITED_LOGIN_PASSWORD_HASH: '' }, { INVITED_LOGIN_PASSWORD_HASH: 'plaintext' },
    { INVITED_LOGIN_EXPIRES_AT: '2020-01-01' }, { INVITED_LOGIN_EXPIRES_AT: '' },
    { INVITED_LOGIN_USER_ID: '' }, { INVITED_LOGIN_USERNAME: '' },
  ])('fails closed for absent, expired or invalid configuration: %j', async (patch) => {
    await expect(verifyInvitedCredentials(config(patch), 'test-invite', password)).resolves.toBeNull();
  });

  function login(user = account()) {
    const repo = {findOne: jest.fn(async () => user), save: jest.fn(), create: jest.fn()};
    const jwt = {sign: jest.fn(() => 'signed-token')};
    const service = new AuthService(repo as any, {} as any, {} as any, jwt as any, config(), {} as any);
    return {service, repo, jwt};
  }

  it('uses ordinary versioned JWT without creating or promoting accounts', async () => {
    const {service, repo, jwt} = login();
    await expect(service.invitedLogin({username: 'test-invite', password})).resolves.toMatchObject({token: 'signed-token'});
    expect(repo.findOne).toHaveBeenCalledWith({where: {id}});
    expect(jwt.sign).toHaveBeenCalledWith({sub: id, tv: 4});
    expect(repo.save).not.toHaveBeenCalled();
    expect(repo.create).not.toHaveBeenCalled();
  });

  it.each([{status: 'deleted'}, {status: 'suspended'}, {role: 'admin'},
    {phone: '0912345678'}, {googleSub: 'google-account'}])('denies forbidden account state: %j', async patch => {
    const {service, jwt} = login({...account(), ...patch} as any);
    await expect(service.invitedLogin({username: 'test-invite', password})).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jwt.sign).not.toHaveBeenCalled();
  });

  it('does not recreate a deleted/missing account', async () => {
    const {service, repo} = login(null as any);
    await expect(service.invitedLogin({username: 'test-invite', password})).rejects.toBeInstanceOf(UnauthorizedException);
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('cannot delete another authenticated account with invited credentials', async () => {
    const repo = {findOne: jest.fn()};
    const service = new UsersService(repo as any, {} as any, {} as any, {} as any, {} as any, {} as any, {} as any, config());
    await expect(service.deleteInvitedAccount('other-id', 'test-invite', password)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(repo.findOne).not.toHaveBeenCalled();
  });

  it('deletes only the verified account and revokes its JWT version', async () => {
    const user = account();
    const repo = {findOne: jest.fn(async () => user), save: jest.fn(async u => u)};
    const builder: any = {};
    for (const method of ['update','set','where']) builder[method] = jest.fn(() => builder);
    builder.execute = jest.fn(async () => undefined);
    const content = {createQueryBuilder: () => builder};
    const qr = {update: jest.fn()};
    const manager = {
      findOne: jest.fn(async () => user), find: jest.fn(async () => []),
      getRepository: () => content, upsert: jest.fn(), update: jest.fn(),
    };
    (repo as any).manager = { transaction: (work: any) => work(manager) };
    const gateway = {disconnectUser: jest.fn()};
    const service = new UsersService(repo as any, {} as any, {} as any, content as any, content as any, qr as any, gateway as any, config());
    await expect(service.deleteInvitedAccount(id, 'test-invite', 'wrong-password-long')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(repo.save).not.toHaveBeenCalled();
    await service.deleteInvitedAccount(id, 'test-invite', password);
    expect(manager.update).toHaveBeenCalledWith(User, {id}, expect.objectContaining({status: 'deleted', tokenVersion: expect.any(Function)}));
    expect(gateway.disconnectUser).toHaveBeenCalledWith(id);
    expect(manager.upsert).toHaveBeenCalled();
  });
});
