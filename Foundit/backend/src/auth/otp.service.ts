import { HttpException, HttpStatus, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomInt, timingSafeEqual } from 'crypto';

interface OtpRecord {
  code: string;
  expiresAt: number;
  attempts: number;
  sentAt: number;
}

/**
 * OTP 暫存。正式環境拒絕 console driver，且未接通供應商時不會回報已寄出。
 * 多實例部署仍應改接 Redis；單進程內以同步檢查做到單次消耗。
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly store = new Map<string, OtpRecord>();
  private readonly sendWindow = new Map<string, number[]>();
  private readonly maxAttempts = 5;
  private readonly resendCooldownMs = 60_000;
  private readonly maxSendsPerTenMinutes = 5;

  constructor(private readonly config: ConfigService) {
    const production = this.config.get<string>('NODE_ENV') === 'production';
    const driver = this.config.get<string>('OTP_DRIVER', 'console');
    if (production && driver === 'console') {
      throw new Error('正式環境禁止 OTP console driver，拒絕啟動');
    }
  }

  async send(phone: string): Promise<void> {
    if (this.config.get<string>('OTP_DRIVER') === 'disabled') {
      throw new ServiceUnavailableException('請使用 Google 帳號登入');
    }
    const now = Date.now();
    this.pruneSends(phone, now);
    const recent = this.sendWindow.get(phone) ?? [];
    if (recent.length >= this.maxSendsPerTenMinutes) {
      throw new HttpException('驗證碼寄送過於頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
    }

    const existing = this.store.get(phone);
    if (existing && now - existing.sentAt < this.resendCooldownMs) {
      throw new HttpException('請稍候再重新取得驗證碼', HttpStatus.TOO_MANY_REQUESTS);
    }

    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresMinutes = Number(this.config.get('OTP_EXPIRES_MINUTES') ?? 5);
    const driver = this.config.get<string>('OTP_DRIVER', 'console');
    if (driver === 'console') {
      this.logger.log(`已產生手機驗證碼（開發模式，不寫入正式日誌內容） phone=${this.mask(phone)}`);
      if (this.config.get<string>('NODE_ENV') === 'development') {
        this.logger.debug(`[OTP] ${this.mask(phone)} ${code}`);
      }
    } else {
      await this.sendViaSms(phone, code);
    }

    this.store.set(phone, {
      code,
      expiresAt: now + expiresMinutes * 60_000,
      attempts: 0,
      sentAt: now,
    });
    recent.push(now);
    this.sendWindow.set(phone, recent);
  }

  verify(phone: string, code: string): boolean {
    if (this.config.get<string>('OTP_DRIVER') === 'disabled') return false;
    const record = this.store.get(phone);
    if (!record) return false;
    if (Date.now() > record.expiresAt) {
      this.store.delete(phone);
      return false;
    }
    record.attempts += 1;
    if (record.attempts > this.maxAttempts) {
      this.store.delete(phone);
      return false;
    }
    const expected = Buffer.from(record.code);
    const given = Buffer.from(code);
    const same = expected.length === given.length && timingSafeEqual(expected, given);
    if (!same) return false;
    this.store.delete(phone);
    return true;
  }

  private async sendViaSms(phone: string, code: string): Promise<void> {
    const sid = this.config.get<string>('TWILIO_ACCOUNT_SID')?.trim();
    const token = this.config.get<string>('TWILIO_AUTH_TOKEN')?.trim();
    const from = this.config.get<string>('TWILIO_FROM_NUMBER')?.trim();
    if (!sid || !token || !from) {
      throw new ServiceUnavailableException('簡訊供應商尚未設定，驗證碼沒有寄出');
    }
    const body = new URLSearchParams({
      To: phone.startsWith('0') ? `+886${phone.slice(1)}` : phone,
      From: from,
      Body: `FOUND !T 驗證碼 ${code}，請勿告知他人。`,
    });
    const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    if (!response.ok) {
      this.logger.warn(`簡訊供應商拒絕寄送 phone=${this.mask(phone)} status=${response.status}`);
      throw new ServiceUnavailableException('驗證碼暫時無法寄出');
    }
  }

  private pruneSends(phone: string, now: number): void {
    const recent = (this.sendWindow.get(phone) ?? []).filter((ts) => now - ts < 10 * 60_000);
    this.sendWindow.set(phone, recent);
  }

  private mask(phone: string): string {
    if (phone.length < 4) return '****';
    return `${phone.slice(0, 2)}****${phone.slice(-2)}`;
  }
}
