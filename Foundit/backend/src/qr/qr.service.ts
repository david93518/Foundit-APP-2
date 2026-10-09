import { BadRequestException, Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { GenerateQrDto, UpdateQrDto } from './dto/generate-qr.dto';
import { findSensitiveData } from '../common/text-safety';

@Injectable()
export class QrService {
  constructor(
    @InjectRepository(QrItem) private readonly qrRepo: Repository<QrItem>,
    private readonly config: ConfigService,
  ) {}

  /**
   * 貼紙上的網址一律用目前的 APP_BASE_URL 重建，修正網域後，尚未印出的舊貼紙也會跟著換成新網址。
   * 查找只看 code，舊網域印出的貼紙在 App 內仍掃得到。
   */
  publicUrl(qrItem: Pick<QrItem, 'code' | 'qrCode'>): string {
    if (!qrItem.code) return qrItem.qrCode;
    return `${this.baseUrl()}/qr/${qrItem.code}`;
  }

  private baseUrl(): string {
    return this.config.get<string>('APP_BASE_URL', 'http://localhost:3000').replace(/\/$/, '');
  }

  async generate(dto: GenerateQrDto, user: User): Promise<QrItem> {
    // 撿到的人掃描後會看到物品名稱；聯絡一律走站內訊息，名稱裡不放電話或 email。
    const sensitive = findSensitiveData(dto.name);
    if (sensitive) throw new BadRequestException(`物品名稱不能包含${sensitive}，撿到的人會透過站內訊息聯絡你`);
    const code = randomUUID();
    const baseUrl = this.baseUrl();
    const qrItem = this.qrRepo.create({
      userId: user.id,
      name: dto.name,
      description: dto.description ?? '',
      code,
      qrCode: `${baseUrl}/qr/${code}`,
      qrImageUrl: '',
    });
    return this.qrRepo.save(qrItem);
  }

  /** 撤銷（刪除）的貼紙保留紀錄給舊對話用，但不再出現在物主的清單。 */
  async findAllByUser(userId: string): Promise<QrItem[]> {
    return this.qrRepo.find({
      where: { userId, revokedAt: IsNull() },
      order: { createdAt: 'DESC' },
    });
  }

  /** 只改名稱與備註；貼紙代碼不變，已經印出來的 QR 繼續有效。 */
  async update(id: string, dto: UpdateQrDto, user: User): Promise<QrItem> {
    const qrItem = await this.qrRepo.findOne({ where: { id } });
    if (!qrItem || qrItem.revokedAt) throw new NotFoundException('QR 物品不存在');
    if (qrItem.userId !== user.id) throw new ForbiddenException('無權限修改此 QR');
    const sensitive = findSensitiveData(dto.name);
    if (sensitive) throw new BadRequestException(`物品名稱不能包含${sensitive}，撿到的人會透過站內訊息聯絡你`);
    qrItem.name = dto.name;
    qrItem.description = dto.description ?? '';
    return this.qrRepo.save(qrItem);
  }

  /** 重複刪除（例如連點兩次）視為成功。 */
  async remove(id: string, user: User): Promise<void> {
    const qrItem = await this.qrRepo.findOne({ where: { id } });
    if (!qrItem) throw new NotFoundException('QR 物品不存在');
    if (qrItem.userId !== user.id) throw new ForbiddenException('無權限刪除此 QR');
    if (qrItem.revokedAt) return;
    qrItem.revokedAt = new Date();
    await this.qrRepo.save(qrItem);
  }

  async scanByCode(code: string): Promise<{ qrItem: QrItem; owner: User }> {
    const normalized = code.trim();
    if (!/^[A-Za-z0-9-]{8,80}$/.test(normalized)) {
      throw new NotFoundException('QR Code 無效或已失效');
    }
    const qrItem = await this.qrRepo
      .createQueryBuilder('qr')
      .leftJoinAndSelect('qr.user', 'user')
      .where('qr.code = :code OR qr.qr_code = :code OR qr.qr_code LIKE :suffix', {
        code: normalized,
        suffix: `%/${normalized}`,
      })
      .getOne();
    if (!qrItem || qrItem.revokedAt || qrItem.user?.status !== 'active') {
      throw new NotFoundException('QR Code 無效或已失效');
    }
    return { qrItem, owner: qrItem.user };
  }
}
