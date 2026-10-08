import { OAuth2Client } from 'google-auth-library';

/** 只接受通過 Google 驗簽、issuer、audience 與期限檢查的 sub。 */
export interface GoogleIdentity {
  sub: string;
  email: string;
  name: string;
  picture: string;
  issuedAt: number;
}

export async function verifyGoogleIdToken(idToken: string, audience: string): Promise<GoogleIdentity> {
  const client = new OAuth2Client(audience);
  const ticket = await client.verifyIdToken({ idToken, audience });
  const payload = ticket.getPayload();
  const sub = payload?.sub;
  if (!sub || payload?.email_verified !== true || !payload.email ||
      payload?.iss !== 'https://accounts.google.com' && payload?.iss !== 'accounts.google.com') {
    throw new Error('Google id_token 缺少有效的 sub 或 issuer');
  }
  return { sub, email: payload.email, name: payload.name ?? '', picture: payload.picture ?? '', issuedAt: payload.iat };
}
