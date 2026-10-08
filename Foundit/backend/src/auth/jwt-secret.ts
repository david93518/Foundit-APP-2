import { ConfigService } from '@nestjs/config';

const EXAMPLE_SECRETS = new Set([
  'fallback-secret',
  'your-super-secret-jwt-key-change-in-production',
  'replace-with-a-long-random-secret',
  'change-me-to-a-different-long-random-secret',
  'secret',
  'changeme',
  'change-me',
]);

/** 讀取 JWT 秘密。禁止靜默退回 fallback-secret；正式環境再拒絕範例值與過短秘密。 */
export function readJwtSecret(config: ConfigService): string {
  const secret = (config.get<string>('JWT_SECRET') ?? '').trim();
  const production = (config.get<string>('NODE_ENV') ?? '') === 'production';
  if (!secret || secret === 'fallback-secret') {
    throw new Error('JWT_SECRET 缺失或仍是 fallback-secret，拒絕啟動');
  }
  if (production && (EXAMPLE_SECRETS.has(secret) || secret.length < 32)) {
    throw new Error('正式環境的 JWT_SECRET 使用範例值或長度不足，拒絕啟動');
  }
  return secret;
}

export function readJwtExpiresIn(config: ConfigService): string {
  const value = (config.get<string>('JWT_EXPIRES_IN') ?? '7d').trim();
  return value || '7d';
}
