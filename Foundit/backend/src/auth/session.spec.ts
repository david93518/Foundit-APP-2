import { UnauthorizedException } from '@nestjs/common';
import { User } from '../common/entities/user.entity';
import { assertActiveSession } from './session';

describe('assertActiveSession', () => {
  const user = { id: 'u1', status: 'active', tokenVersion: 2 } as User;

  it('accepts the current token version', () => {
    expect(assertActiveSession(user, 2)).toBe(user);
  });

  it('rejects a missing user, a suspended account, and an old token', () => {
    expect(() => assertActiveSession(null, 2)).toThrow(UnauthorizedException);
    expect(() => assertActiveSession({ ...user, status: 'suspended' } as User, 2)).toThrow(UnauthorizedException);
    expect(() => assertActiveSession(user, 1)).toThrow(UnauthorizedException);
    expect(() => assertActiveSession(user, undefined)).toThrow(UnauthorizedException);
  });
});
