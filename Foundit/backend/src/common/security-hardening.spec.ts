import { HttpException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { of } from 'rxjs';
import { clientIp, isPrivateAddress } from './client-ip';
import { AbuseLimitInterceptor, limiterKeyForIp, RateLimit } from './abuse-limit.interceptor';
import { isGoogleAvatar, isOwnUpload, isOwnUploadName, newUploadName, publicBaseUrl } from './media-url';
import { hasAllowedSignature } from '../upload/upload.controller';
import { toMobileItem } from '../items/item-mobile.serializer';
import { Item } from './entities/item.entity';

const OWNER = '6c628b21-c68a-45c5-96a0-558ccf344819';
const OTHER = '11111111-1111-4111-8111-111111111111';
const FILE = '22222222-2222-4222-8222-222222222222';
const BASE = 'https://api.foundit.tw';

describe('clientIp', () => {
  it('trusts the proxy header only when the TCP peer is the local proxy', () => {
    const viaTunnel = { socket: { remoteAddress: '::ffff:172.18.0.1' }, headers: { 'cf-connecting-ip': '203.0.113.9' } };
    expect(clientIp(viaTunnel)).toBe('172.18.0.1');
    process.env.TRUSTED_PROXY_ADDRESSES = '127.0.0.1,::1,172.18.0.1';
    expect(clientIp(viaTunnel)).toBe('203.0.113.9');
    delete process.env.TRUSTED_PROXY_ADDRESSES;
    const direct = { socket: { remoteAddress: '198.51.100.7' }, headers: { 'cf-connecting-ip': '203.0.113.9' } };
    expect(clientIp(direct)).toBe('198.51.100.7');
    const garbage = { socket: { remoteAddress: '127.0.0.1' }, headers: { 'cf-connecting-ip': 'evil, 1.2.3.4' } };
    expect(clientIp(garbage)).toBe('127.0.0.1');
  });

  it('recognises private and public peers', () => {
    expect(isPrivateAddress('10.0.0.1')).toBe(true);
    expect(isPrivateAddress('::1')).toBe(true);
    expect(isPrivateAddress('172.32.0.1')).toBe(false);
    expect(isPrivateAddress('8.8.8.8')).toBe(false);
  });

  it('groups IPv6 clients by /64', () => {
    expect(limiterKeyForIp('2001:db8:1:2:aaaa::1')).toBe('2001:db8:1:2::/64');
    expect(limiterKeyForIp('2001:db8:1:2:ffff:ffff:ffff:ffff')).toBe('2001:db8:1:2::/64');
    expect(limiterKeyForIp('2001:db8::1')).toBe('2001:db8:0:0::/64');
    expect(limiterKeyForIp('203.0.113.9')).toBe('203.0.113.9');
  });
});

describe('AbuseLimitInterceptor', () => {
  class Target {
    @RateLimit({ name: 'login', limit: 2, windowMs: 60_000, by: 'ip' })
    login() {}
  }

  function call(interceptor: AbuseLimitInterceptor, ip: string, user?: string) {
    const request = { socket: { remoteAddress: '127.0.0.1' }, headers: { 'cf-connecting-ip': ip }, user: user ? { id: user } : undefined };
    const context = {
      getType: () => 'http',
      getHandler: () => Target.prototype.login,
      switchToHttp: () => ({ getRequest: () => request, getResponse: () => ({ setHeader: jest.fn() }) }),
    };
    return interceptor.intercept(context as never, { handle: () => of(true) });
  }

  it('limits by route metadata regardless of how the URL was spelled', () => {
    const interceptor = new AbuseLimitInterceptor(new Reflector());
    call(interceptor, '203.0.113.1');
    call(interceptor, '203.0.113.1');
    expect(() => call(interceptor, '203.0.113.1')).toThrow(HttpException);
    // 不同的真實來源各自計算，不會因為都經過同一個 Tunnel 而互相拖累。
    expect(() => call(interceptor, '203.0.113.2')).not.toThrow();
  });
});

describe('media URL allow-list', () => {
  const SECRET = 'test-secret-test-secret-test-secret';
  const name = newUploadName(OWNER, SECRET);
  const own = `${BASE}/uploads/${name}`;
  const legacy = `${BASE}/uploads/${OWNER}_${FILE}.jpg`;

  it('signs file names without revealing or linking the uploader', () => {
    expect(name).not.toContain(OWNER);
    expect(newUploadName(OWNER, SECRET).split('_')[1]).not.toBe(name.split('_')[1]);
    expect(isOwnUploadName(name, OWNER, SECRET)).toBe(true);
    expect(isOwnUploadName(name, OTHER, SECRET)).toBe(false);
    expect(isOwnUploadName(name, OWNER, 'another-secret')).toBe(false);
    expect(isOwnUploadName(`${name.split('_')[0]}_${'0'.repeat(32)}.jpg`, OWNER, SECRET)).toBe(false);
  });

  it('accepts only the caller’s own uploads on this origin', () => {
    expect(isOwnUpload(own, OWNER, BASE, SECRET)).toBe(true);
    expect(isOwnUpload(legacy, OWNER, BASE, SECRET)).toBe(true);
    expect(isOwnUpload(own, OTHER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(legacy, OTHER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(`https://api.foundit.tw.evil.example/uploads/${name}`, OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(`https://api.foundit.tw@evil.example/uploads/${name}`, OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(`http://api.foundit.tw/uploads/${name}`, OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(`${own}?track=1`, OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(`${BASE}/uploads/../uploads/${name}`, OWNER, BASE, SECRET)).toBe(true);
    expect(isOwnUpload(`${BASE}/uploads/%2e%2e/${name}`, OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload('javascript:alert(1)', OWNER, BASE, SECRET)).toBe(false);
    expect(isOwnUpload(own, OWNER, null, SECRET)).toBe(false);
  });

  it('accepts Google profile pictures only over https on googleusercontent.com', () => {
    expect(isGoogleAvatar('https://lh3.googleusercontent.com/a/abc=s96-c')).toBe(true);
    expect(isGoogleAvatar('http://lh3.googleusercontent.com/a/abc')).toBe(false);
    expect(isGoogleAvatar('https://googleusercontent.com.evil.example/a')).toBe(false);
  });

  it('refuses to guess a public origin in production', () => {
    expect(publicBaseUrl({ get: (key: string) => (key === 'NODE_ENV' ? 'production' : undefined) } as never)).toBeNull();
    expect(publicBaseUrl({ get: (key: string) => (key === 'APP_BASE_URL' ? 'https://api.foundit.tw/' : undefined) } as never))
      .toBe('https://api.foundit.tw');
  });
});

describe('upload signature gate', () => {
  it('lets only raster formats reach the decoder', () => {
    expect(hasAllowedSignature(Buffer.from('ffd8ffe000104a4649460001', 'hex'))).toBe(true);
    expect(hasAllowedSignature(Buffer.from('89504e470d0a1a0a0000000d', 'hex'))).toBe(true);
    expect(hasAllowedSignature(Buffer.from('RIFF\0\0\0\0WEBPVP8 ', 'latin1'))).toBe(true);
    expect(hasAllowedSignature(Buffer.from('\0\0\0\x18ftypheic\0\0\0\0', 'latin1'))).toBe(true);
    expect(hasAllowedSignature(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg">', 'latin1'))).toBe(false);
    expect(hasAllowedSignature(Buffer.from('%PDF-1.7\n%âãÏÓ', 'latin1'))).toBe(false);
    expect(hasAllowedSignature(Buffer.from('49492a0008000000', 'hex'))).toBe(false);
  });
});

describe('item serializer', () => {
  const item = { id: FILE, userId: OWNER, title: 't', images: [] } as unknown as Item;

  it('reveals the poster id only to the poster', () => {
    expect(toMobileItem(item, OWNER).user_id).toBe(OWNER);
    expect(toMobileItem(item, OTHER).user_id).toBe('');
    expect(toMobileItem(item, null).user_id).toBe('');
  });
});
