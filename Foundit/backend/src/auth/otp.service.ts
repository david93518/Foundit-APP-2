import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface OtpRecord {
  code: string;
  expiresAt: Date;
  attempts: number;
}

/**
 * OTP 服務：開發環境印 Log，正式環境接 SMS 簡訊商（EVERY8D / Twilio）。
 * OTP 暫存於記憶體；正式環境應改用 Redis 儲存。
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly store = new Map<string, OtpRecord>();
  private readonly MAX_ATTEMPTS = 5;

  constructor(private readonly config: ConfigService) {}

  /** 產生並發送 OTP */
  async send(phone: string): Promise<void> {
    const code = this.generateCode();
    const expiresMinutes = this.config.get<number>('OTP_EXPIRES_MINUTES', 5);
    const expiresAt = new Date(Date.now() + expiresMinutes * 60 * 1000);

    this.store.set(phone, { code, expiresAt, attempts: 0 });

    const driver = this.config.get<string>('OTP_DRIVER', 'console');
    if (driver === 'console') {
      this.logger.log(`[OTP] 手機 ${phone} 驗證碼：${code}（${expiresMinutes} 分鐘有效）`);
    } else {
      await this.sendViaSms(phone, code);
    }
  }

  /** 驗證 OTP，成功後刪除記錄 */
  verify(phone: string, code: string): boolean {
    const record = this.store.get(phone);
    if (!record) return false;
    if (new Date() > record.expiresAt) {
      this.store.delete(phone);
      return false;
    }
    record.attempts++;
    if (record.attempts > this.MAX_ATTEMPTS) {
      this.store.delete(phone);
      return false;
    }
    if (record.code !== code) return false;
    this.store.delete(phone);
    return true;
  }

  private generateCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private async sendViaSms(phone: string, code: string): Promise<void> {
    // TODO: 串接 EVERY8D 或 Twilio
    this.logger.warn(`SMS 未設定，OTP ${code} 無法傳送至 ${phone}`);
  }
}
