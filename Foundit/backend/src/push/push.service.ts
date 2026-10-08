import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';
import { existsSync, readFileSync } from 'fs';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

export type PushMessage = {
  title: string;
  body: string;
  /** FCM data 只接受字串值。 */
  data: Record<string, string>;
  /** 同一個對話的通知互相取代，鎖屏不會堆滿同一個人的訊息。 */
  collapseKey: string;
  badge?: number;
};

export type PushResult = 'sent' | 'invalid-token' | 'failed' | 'disabled';

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

/**
 * FCM HTTP v1。用服務帳戶自行簽 JWT 換 access token，不另外引入 firebase-admin。
 * 未設定 FCM_SERVICE_ACCOUNT_FILE / FCM_SERVICE_ACCOUNT_JSON 時整個服務停用，聊天照常運作。
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private readonly account: ServiceAccount | null;
  private accessToken: { value: string; expiresAt: number } | null = null;

  constructor(config: ConfigService) {
    this.account = this.loadAccount(config);
    if (!this.account) this.logger.warn('FCM 推播未設定，新訊息只會在 App 內顯示');
  }

  get enabled(): boolean {
    return this.account != null;
  }

  async send(token: string | null | undefined, message: PushMessage): Promise<PushResult> {
    if (!this.account) return 'disabled';
    if (!token) return 'failed';
    try {
      const res = await this.post(
        `https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`,
        { authorization: `Bearer ${await this.token()}`, 'content-type': 'application/json' },
        JSON.stringify({ message: this.toFcm(token, message) }),
      );
      if (res.status >= 200 && res.status < 300) return 'sent';
      // 404 UNREGISTERED：App 已移除或 token 輪替；400 只在錯誤明確指向 token 時才視為失效。
      const detail = res.body;
      if (res.status === 404 || /UNREGISTERED|SENDER_ID_MISMATCH/.test(detail)
        || (res.status === 400 && /registration token/i.test(detail))) {
        return 'invalid-token';
      }
      if (res.status === 401) this.accessToken = null;
      this.logger.warn(`FCM 發送失敗 status=${res.status}`);
      return 'failed';
    } catch (error) {
      this.logger.warn(`FCM 發送失敗：${(error as Error).message}`);
      return 'failed';
    }
  }

  private toFcm(token: string, m: PushMessage): Record<string, unknown> {
    return {
      token,
      notification: { title: m.title, body: m.body },
      data: m.data,
      android: {
        priority: 'high',
        collapse_key: m.collapseKey,
        notification: { tag: m.collapseKey, sound: 'default' },
      },
      apns: {
        headers: { 'apns-collapse-id': m.collapseKey.slice(0, 64) },
        payload: {
          aps: {
            sound: 'default',
            'thread-id': m.collapseKey,
            ...(m.badge != null ? { badge: m.badge } : {}),
          },
        },
      },
    };
  }

  private async token(): Promise<string> {
    const now = Date.now();
    if (this.accessToken && this.accessToken.expiresAt - 60_000 > now) return this.accessToken.value;
    const account = this.account!;
    const iat = Math.floor(now / 1000);
    const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
      iss: account.client_email,
      scope: SCOPE,
      aud: TOKEN_URL,
      iat,
      exp: iat + 3600,
    })}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
    const res = await this.post(
      TOKEN_URL,
      { 'content-type': 'application/x-www-form-urlencoded' },
      new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${unsigned}.${signature}`,
      }).toString(),
    );
    if (res.status !== 200) throw new Error(`無法取得 FCM 授權 status=${res.status}`);
    const body = JSON.parse(res.body) as { access_token: string; expires_in: number };
    this.accessToken = { value: body.access_token, expiresAt: now + body.expires_in * 1000 };
    return body.access_token;
  }

  /** 測試時覆寫，避免真的連線。 */
  protected async post(
    url: string,
    headers: Record<string, string>,
    body: string,
  ): Promise<{ status: number; body: string }> {
    const res = await fetch(url, { method: 'POST', headers, body, signal: AbortSignal.timeout(8000) });
    return { status: res.status, body: await res.text() };
  }

  private loadAccount(config: ConfigService): ServiceAccount | null {
    const file = config.get<string>('FCM_SERVICE_ACCOUNT_FILE')?.trim();
    const inline = config.get<string>('FCM_SERVICE_ACCOUNT_JSON')?.trim();
    let raw: string | null = null;
    if (file) {
      if (!existsSync(file)) {
        this.logger.error(`找不到 FCM 服務帳戶檔案：${file}`);
        return null;
      }
      raw = readFileSync(file, 'utf8');
    } else if (inline) {
      raw = inline.startsWith('{') ? inline : Buffer.from(inline, 'base64').toString('utf8');
    }
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw) as Partial<ServiceAccount>;
      if (!parsed.project_id || !parsed.client_email || !parsed.private_key) throw new Error('缺少欄位');
      return { project_id: parsed.project_id, client_email: parsed.client_email, private_key: parsed.private_key };
    } catch {
      this.logger.error('FCM 服務帳戶格式不正確，推播停用');
      return null;
    }
  }
}
