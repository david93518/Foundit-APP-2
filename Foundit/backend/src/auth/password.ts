import { createHash, randomBytes, scrypt, timingSafeEqual } from 'crypto';

// Email + password accounts (the web's second sign-in method, kept apart from Google accounts).
// Passwords are stored as scrypt hashes: `scrypt$N$r$p$<salt base64>$<hash base64>`.

const N = 16384;
const R = 8;
const P = 1;
const KEY_LENGTH = 64;

export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 128;

function derive(password: string, salt: Buffer, n = N, r = R, p = P): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(password, salt, KEY_LENGTH, { N: n, r, p, maxmem: 64 * 1024 * 1024 }, (error, key) => (error ? reject(error) : resolve(key))),
  );
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await derive(password, salt);
  return `scrypt$${N}$${R}$${P}$${salt.toString('base64')}$${key.toString('base64')}`;
}

/** False for a wrong password and for anything that is not one of our hashes. */
export async function verifyPassword(password: string, stored: string | null | undefined): Promise<boolean> {
  const parts = String(stored ?? '').split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const [, n, r, p, salt, hash] = parts;
  const expected = Buffer.from(hash, 'base64');
  if (expected.length !== KEY_LENGTH) return false;
  const key = await derive(password, Buffer.from(salt, 'base64'), Number(n), Number(r), Number(p));
  return timingSafeEqual(key, expected);
}

/** A login with an unknown email still spends the same time, so response times do not reveal who has an account. */
export async function burnPasswordCheck(password: string): Promise<void> {
  await derive(password, Buffer.alloc(16));
}

export const normalizeEmail = (email: string): string => String(email ?? '').trim().toLowerCase();

/**
 * The account key in users.phone (unique): `e:` and a hash of the email. Google accounts use `g:<sub>`, so the
 * same email can have a Google account and a separate email account, and the email itself is not exposed as a phone.
 */
export const emailAccountKey = (email: string): string => `e:${createHash('sha256').update(normalizeEmail(email)).digest('hex')}`;
