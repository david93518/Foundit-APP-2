import { OAuth2Client } from 'google-auth-library';

/** 只接受通過 Google 驗簽、issuer、audience 與期限檢查的 sub。 */
export interface GoogleIdentity {
  sub: string;
  email: string;
  name: string;
  picture: string;
  issuedAt: number;
}

// 共用 client 才會快取 Google 的簽章公鑰，不必每次登入都重抓。
const clients = new Map<string, OAuth2Client>();

export async function verifyGoogleIdToken(idToken: string, audience: string): Promise<GoogleIdentity> {
  if (typeof idToken !== 'string' || idToken.length > 8192) throw new Error('Google id_token 格式不正確');
  let client = clients.get(audience);
  if (!client) {
    client = new OAuth2Client(audience);
    clients.set(audience, client);
  }
  const ticket = await client.verifyIdToken({ idToken, audience });
  const payload = ticket.getPayload();
  const sub = payload?.sub;
  if (!sub || payload?.email_verified !== true || !payload.email ||
      payload?.iss !== 'https://accounts.google.com' && payload?.iss !== 'accounts.google.com') {
    throw new Error('Google id_token 缺少有效的 sub 或 issuer');
  }
  return { sub, email: payload.email, name: payload.name ?? '', picture: payload.picture ?? '', issuedAt: payload.iat };
}
