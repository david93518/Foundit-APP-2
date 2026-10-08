import { UnauthorizedException } from '@nestjs/common';
import { User } from '../common/entities/user.entity';

export interface AccessTokenPayload {
  sub: string;
  tv: number;
}

export function assertActiveSession(user: User | null, tokenVersion: number | undefined): User {
  if (!user || user.status !== 'active') {
    throw new UnauthorizedException('登入已失效');
  }
  if (tokenVersion == null || tokenVersion !== user.tokenVersion) {
    throw new UnauthorizedException('登入已失效');
  }
  return user;
}
