import {
  BadRequestException,
  GoneException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Raw, Repository } from 'typeorm';
import { createHash, createHmac, randomBytes } from 'crypto';
import { LineLink } from '../common/entities/line-link.entity';
import { QrFinderNotice } from '../common/entities/qr-finder-notice.entity';
import { NotificationType } from '../common/entities/notification.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { PushService } from '../push/push.service';
import { QrService } from '../qr/qr.service';
import { FinderNoticeDto } from './dto/line.dto';

export const LINK_USES = 3;
export const LINKS_PER_HOUR = 10;
export const NOTICES_PER_HOUR = 10;

/**
 * 「最近一小時」交給資料庫算。created_at 是不含時區的 timestamp，
 * 拿應用程式的時間去比，只要兩邊時區設定不同就會算錯。
 */
const withinLastHour = () => Raw((column) => `${column} > now() - interval '1 hour'`);

export type LinkStatus =
  | { status: 'ok'; usesLeft: number; expiresAt: Date }
  | { status: 'expired' | 'used' | 'invalid' };

@Injectable()
export class LineService {
  private readonly logger = new Logger(LineService.name);

  constructor(
    @InjectRepository(LineLink) private readonly linkRepo: Repository<LineLink>,
    private readonly dataSource: DataSource,
    private readonly qr: QrService,
    private readonly notifications: NotificationsService,
    private readonly push: PushService,
    private readonly config: ConfigService,
  ) {}

  /** 連結只存雜湊：資料庫外洩也拿不到可用的連結。 */
  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /** 用密鑰加鹽，資料庫看不出是哪個 LINE 使用者，但同一個人永遠得到同一個值（用來限流）。 */
  private hashLineUser(lineUser: string): string {
    return createHmac('sha256', this.config.get<string>('LINE_BOT_SECRET', '')).update(`line-user:${lineUser}`).digest('hex');
  }

  async issueLink(lineUser: string, ttlMinutes = 60): Promise<{ token: string; expiresAt: Date; uses: number }> {
    const lineUserHash = this.hashLineUser(lineUser);
    const recent = await this.linkRepo.count({
      where: { lineUserHash, createdAt: withinLastHour() },
    });
    if (recent >= LINKS_PER_HOUR) {
      throw new HttpException('操作太頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
    }
    const token = randomBytes(24).toString('base64url');
    const expiresAt = new Date(Date.now() + Math.min(Math.max(ttlMinutes, 5), 1440) * 60_000);
    await this.linkRepo.save(
      this.linkRepo.create({ tokenHash: this.hashToken(token), lineUserHash, expiresAt, usesLeft: LINK_USES }),
    );
    return { token, expiresAt, uses: LINK_USES };
  }

  async status(token: string): Promise<LinkStatus> {
    const link = await this.linkRepo.findOne({ where: { tokenHash: this.hashToken(token) } });
    if (!link) return { status: 'invalid' };
    if (link.expiresAt.getTime() <= Date.now()) return { status: 'expired' };
    if (link.usesLeft <= 0) return { status: 'used' };
    return { status: 'ok', usesLeft: link.usesLeft, expiresAt: link.expiresAt };
  }

  /**
   * 撿到的人留言給物主。代碼只有 6 碼，所以連結的次數也是防猜碼的關卡：
   * 每次嘗試（包含打錯代碼）都用掉一次，一個連結最多 3 次，一個 LINE 使用者每小時最多 10 個連結。
   * 被頻率限制擋下的請求不會消耗次數。留言紀錄與通知只在代碼正確時才寫。
   */
  async notifyOwner(token: string, dto: FinderNoticeDto): Promise<{ name: string; usesLeft: number }> {
    const message = dto.message.trim();
    if (!message) throw new BadRequestException('請寫下留言');
    const contact = dto.contact?.trim() || null;

    let found: Awaited<ReturnType<QrService['scanByCode']>> | null = null;
    let lookupError: unknown = null;
    try {
      found = await this.qr.scanByCode(dto.code);
    } catch (error) {
      lookupError = error;
    }

    const usesLeft = await this.dataSource.transaction(async (manager) => {
      const link = await manager.findOne(LineLink, {
        where: { tokenHash: this.hashToken(token) },
        lock: { mode: 'pessimistic_write' },
      });
      if (!link) throw new NotFoundException('連結無效');
      if (link.expiresAt.getTime() <= Date.now()) throw new GoneException('連結已過期，請回 LINE 重新取得');
      if (link.usesLeft <= 0) throw new GoneException('連結已用完，請回 LINE 重新取得');

      const sent = await manager.count(QrFinderNotice, {
        where: { lineUserHash: link.lineUserHash, createdAt: withinLastHour() },
      });
      if (sent >= NOTICES_PER_HOUR) {
        throw new HttpException('操作太頻繁，請稍後再試', HttpStatus.TOO_MANY_REQUESTS);
      }

      link.usesLeft -= 1;
      await manager.save(link);
      if (found) {
        await manager.save(
          manager.create(QrFinderNotice, { qrItemId: found.qrItem.id, lineUserHash: link.lineUserHash, message, contact }),
        );
      }
      return link.usesLeft;
    });

    if (!found) {
      if (lookupError instanceof NotFoundException) {
        const left = usesLeft > 0 ? `，這個連結還能再試 ${usesLeft} 次` : '，這個連結已用完，請回 LINE 重新取得';
        throw new NotFoundException(`${lookupError.message}${left}`);
      }
      throw lookupError;
    }
    await this.tellOwner(found.owner.id, found.owner.fcmToken, found.qrItem.name, message, contact);
    return { name: found.qrItem.name, usesLeft };
  }

  private async tellOwner(
    ownerId: string,
    fcmToken: string | null | undefined,
    tagName: string,
    message: string,
    contact: string | null,
  ): Promise<void> {
    const title = `有人撿到你的「${tagName.length > 60 ? `${tagName.slice(0, 59)}…` : tagName}」`;
    const content = contact ? `${message}\n對方留的聯絡方式：${contact}` : message;
    await this.notifications.create({ userId: ownerId, type: NotificationType.QR_SCAN, title, content });
    if (this.push.enabled && fcmToken) {
      // 推播失敗不影響留言：站內通知已經存好了。
      this.push
        .send(fcmToken, { title, body: message.slice(0, 120), data: { type: 'qr_scan' }, collapseKey: 'qr-scan' })
        .catch((error: unknown) => this.logger.warn(`推播失敗：${String(error)}`));
    }
  }
}
