import { ConfigService } from '@nestjs/config';
import { createHash, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const derive = promisify(scrypt);

/** An explicitly provisioned ordinary account; never substitutes for Google/OTP. */
export async function verifyInvitedCredentials(
  config: ConfigService, username: string, password: string,
): Promise<string | null> {
  const expected = config.get<string>('INVITED_LOGIN_USERNAME') ?? '';
  const id = config.get<string>('INVITED_LOGIN_USER_ID') ?? '';
  const expiry = Date.parse(config.get<string>('INVITED_LOGIN_EXPIRES_AT') ?? '');
  const hash = config.get<string>('INVITED_LOGIN_PASSWORD_HASH') ?? '';
  const match = /^scrypt:([0-9a-f]{32}):([0-9a-f]{128})$/.exec(hash);
  if (!/^[a-z0-9][a-z0-9._-]{2,63}$/.test(expected) ||
      !/^[0-9a-f-]{36}$/i.test(id) || !Number.isFinite(expiry) || expiry <= Date.now() ||
      !match || typeof username !== 'string' || typeof password !== 'string' ||
      password.length < 12 || password.length > 128) return null;
  const actual = await derive(password, Buffer.from(match[1], 'hex'), 64) as Buffer;
  const samePassword = timingSafeEqual(actual, Buffer.from(match[2], 'hex'));
  const digest = (value: string) => createHash('sha256').update(value).digest();
  const sameName = timingSafeEqual(digest(username), digest(expected));
  return sameName && samePassword ? id : null;
}
