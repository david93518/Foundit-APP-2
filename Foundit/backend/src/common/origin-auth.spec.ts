import { allowedOrigin, authenticatedOrigin } from './origin-auth';
import { clientIp } from './client-ip';

describe('authenticated Cloudflare ingress', () => {
  const previous = process.env.ORIGIN_PROXY_SECRET;
  afterEach(() => { if (previous === undefined) delete process.env.ORIGIN_PROXY_SECRET; else process.env.ORIGIN_PROXY_SECRET = previous; });
  it('preserves existing deployments when no ingress secret is configured', () => {
    delete process.env.ORIGIN_PROXY_SECRET;
    expect(allowedOrigin({ headers: {} })).toBe(true);
    expect(authenticatedOrigin({ headers: {} })).toBe(false);
  });
  it('rejects missing, incorrect and array credentials', () => {
    process.env.ORIGIN_PROXY_SECRET = 'test-secret';
    for (const value of [undefined, 'bad', ['test-secret']]) {
      expect(allowedOrigin({ headers: { 'x-foundit-origin-token': value } })).toBe(false);
    }
  });
  it('trusts client addresses only after authenticating the proxy', () => {
    process.env.ORIGIN_PROXY_SECRET = 'test-secret';
    const request = { socket: { remoteAddress: '198.51.100.5' }, headers: {
      'x-foundit-origin-token': 'test-secret', 'x-foundit-client-ip': '203.0.113.10' } };
    expect(clientIp(request)).toBe('203.0.113.10');
    request.headers['x-foundit-origin-token'] = 'attacker';
    expect(clientIp(request)).toBe('198.51.100.5');
  });
});
