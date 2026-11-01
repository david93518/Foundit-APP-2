import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { NotificationType } from '../common/entities/notification.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { PushService } from '../push/push.service';

export type ScanSource = 'app' | 'web';

/** 連結預覽與爬蟲也會打開貼紙網址；它們不是撿到東西的人，不該讓物主收到通知。 */
const BOT_AGENT = /bot|crawl|spider|slurp|preview|facebookexternalhit|embedly|whatsapp|telegram|discord|skype|curl|wget|python|okhttp|go-http|headless/i;

/**
 * 有人掃描防丟牌時通知物主。只說「有人掃了哪一張」，不透露掃描者是誰、在哪裡：
 * 對方還沒決定聯絡，物主也不需要知道更多。同一張貼紙短時間內只通知一次，避免被重複掃描洗版。
 */
@Injectable()
export class QrScanNotifier {
  private readonly logger = new Logger(QrScanNotifier.name);
  private readonly lastNotified = new Map<string, number>();
  private readonly windowMs = 15 * 60_000;

  constructor(
    private readonly notifications: NotificationsService,
    private readonly push: PushService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  /** 網頁掃描只接受看起來是手機瀏覽器的請求。 */
  static isHumanBrowser(userAgent: string | undefined): boolean {
    if (!userAgent || BOT_AGENT.test(userAgent)) return false;
    return /iphone|ipad|android|mobile/i.test(userAgent);
  }

  /** 不等待、不拋錯：通知失敗不能影響掃描結果。 */
  scanned(qrItem: QrItem, owner: User, source: ScanSource): void {
    if (!this.claim(qrItem.id)) return;
    void this.deliver(qrItem, owner, source).catch((error: unknown) => {
      this.logger.warn(`防丟牌掃描通知失敗：${(error as Error)?.message ?? error}`);
    });
  }

  private claim(qrItemId: string): boolean {
    const now = Date.now();
    const last = this.lastNotified.get(qrItemId);
    if (last != null && now - last < this.windowMs) return false;
    this.lastNotified.set(qrItemId, now);
    if (this.lastNotified.size > 10_000) {
      for (const [id, at] of this.lastNotified) {
        if (now - at >= this.windowMs) this.lastNotified.delete(id);
      }
    }
    return true;
  }

  private async deliver(qrItem: QrItem, owner: User, source: ScanSource): Promise<void> {
    const title = '有人掃描了你的防丟牌';
    const content = source === 'app'
      ? `有人在 FOUND !T 掃描了「${qrItem.name}」。對方傳訊息時，會出現在「訊息」。`
      : `有人用手機相機掃描了「${qrItem.name}」。對方開啟 FOUND !T 後就能傳訊息給你。`;
    await this.notifications.create({ userId: owner.id, type: NotificationType.QR_SCAN, title, content });
    if (!this.push.enabled || !owner.fcmToken) return;
    const result = await this.push.send(owner.fcmToken, {
      title,
      body: content,
      data: { type: 'qr_scan' },
      collapseKey: `qr-${qrItem.id}`,
    });
    if (result === 'invalid-token') {
      await this.userRepo.update({ id: owner.id, fcmToken: owner.fcmToken }, { fcmToken: null });
    }
  }
}
