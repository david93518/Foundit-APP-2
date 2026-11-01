import { CODE_ALPHABET, CODE_LENGTH, newStickerCode, normalizeCode } from './sticker-code';

describe('sticker codes', () => {
  it('makes 8 characters from the unambiguous alphabet', () => {
    for (let i = 0; i < 200; i += 1) {
      const code = newStickerCode();
      expect(code).toHaveLength(CODE_LENGTH);
      for (const ch of code) expect(CODE_ALPHABET).toContain(ch);
    }
    expect(CODE_ALPHABET).not.toMatch(/[IO01]/);
  });

  it('matches the pattern the LINE webhook looks for', () => {
    expect(newStickerCode()).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
  });

  it('uppercases new 8-character codes and trims input', () => {
    expect(normalizeCode('  k7m2p9qx ')).toBe('K7M2P9QX');
  });

  it('pulls the code out of a pasted sticker URL', () => {
    expect(normalizeCode('https://app.foundit.tw/qr/k7m2p9qx')).toBe('K7M2P9QX');
    expect(normalizeCode('https://app.foundit.tw/qr/K7M2P9QX?x=1')).toBe('K7M2P9QX');
  });

  it('keeps legacy UUID codes as they are', () => {
    const legacy = '8f0c1f8e-2a3b-4c5d-9e6f-0a1b2c3d4e5f';
    expect(normalizeCode(legacy)).toBe(legacy);
  });

  it('rejects malformed input', () => {
    expect(normalizeCode('')).toBeNull();
    expect(normalizeCode('short')).toBeNull();
    expect(normalizeCode('../../etc/passwd')).toBeNull();
    expect(normalizeCode("K7M2P9Q'; DROP")).toBeNull();
  });
});
