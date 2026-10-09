import { isIP } from 'net';

/**
 * 正式環境的請求都經過 Cloudflare Tunnel：TCP 對端永遠是本機或 Docker 內網，
 * 用它當限流鍵會讓所有人共用一個額度。只有 TCP 對端在 TRUSTED_PROXY_ADDRESSES
 * 明確白名單時才採信代理標頭；其餘請求都採用 TCP 對端位址。
 */
const PROXY_HEADER = (process.env.CLIENT_IP_HEADER ?? 'cf-connecting-ip').trim().toLowerCase();

function stripMapped(address: string): string {
  return address.startsWith('::ffff:') ? address.slice(7) : address;
}

export function isPrivateAddress(raw: string | undefined | null): boolean {
  if (!raw) return false;
  const address = stripMapped(raw);
  if (isIP(address) === 4) {
    const [a, b] = address.split('.').map(Number);
    return a === 127 || a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
  }
  if (isIP(address) === 6) {
    const lower = address.toLowerCase();
    return lower === '::1' || lower.startsWith('fc') || lower.startsWith('fd') || lower.startsWith('fe80:');
  }
  return false;
}

export function clientIp(request: {
  headers?: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
  connection?: { remoteAddress?: string };
}): string {
  const peer = request.socket?.remoteAddress ?? request.connection?.remoteAddress ?? '';
  // Only explicitly listed proxy peers may supply a client address. A private subnet is not a trust boundary.
  const trusted = (process.env.TRUSTED_PROXY_ADDRESSES ?? '127.0.0.1,::1')
    .split(',').map(address => stripMapped(address.trim()));
  if (PROXY_HEADER && trusted.includes(stripMapped(peer))) {
    const header = request.headers?.[PROXY_HEADER];
    const value = (Array.isArray(header) ? header[0] : header)?.trim();
    if (value && isIP(value)) return stripMapped(value);
  }
  return stripMapped(peer) || 'unknown';
}
