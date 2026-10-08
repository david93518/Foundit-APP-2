import { ConfigService } from '@nestjs/config';
import { readJwtSecret } from './jwt-secret';

function config(values: Record<string, string>): ConfigService {
  return { get: (key: string) => values[key] } as ConfigService;
}

describe('readJwtSecret', () => {
  it('rejects a missing secret and the old fallback', () => {
    expect(() => readJwtSecret(config({}))).toThrow(/JWT_SECRET/);
    expect(() => readJwtSecret(config({ JWT_SECRET: 'fallback-secret' }))).toThrow(/fallback-secret/);
  });

  it('rejects example secrets only in production', () => {
    const example = 'your-super-secret-jwt-key-change-in-production';
    expect(readJwtSecret(config({ JWT_SECRET: example, NODE_ENV: 'development' }))).toBe(example);
    expect(() => readJwtSecret(config({ JWT_SECRET: example, NODE_ENV: 'production' }))).toThrow(/範例值/);
    expect(() => readJwtSecret(config({ JWT_SECRET: 'replace-with-a-long-random-secret', NODE_ENV: 'production' }))).toThrow(/範例值/);
    expect(() => readJwtSecret(config({ JWT_SECRET: 'short-but-not-fallback', NODE_ENV: 'production' }))).toThrow(/長度不足/);
  });
});
