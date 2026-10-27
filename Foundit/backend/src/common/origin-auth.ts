import { timingSafeEqual } from 'crypto';

export function authenticatedOrigin(request: { headers?: Record<string, string | string[] | undefined> }): boolean {
  const expected = process.env.ORIGIN_PROXY_SECRET;
  const actual = request.headers?.['x-foundit-origin-token'];
  if (!expected || typeof actual !== 'string') return false;
  const a = Buffer.from(actual);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function allowedOrigin(request: { headers?: Record<string, string | string[] | undefined> }): boolean {
  return !process.env.ORIGIN_PROXY_SECRET || authenticatedOrigin(request);
}
