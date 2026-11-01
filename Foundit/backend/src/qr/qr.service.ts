import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  GoneException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { QrItem } from '../common/entities/qr-item.entity';
import { QrBatch } from '../common/entities/qr-batch.entity';
import { User } from '../common/entities/user.entity';
import { GenerateQrDto } from './dto/generate-qr.dto';
import { BindQrDto, UpdateQrDto } from './dto/bind-qr.dto';
import { CreateQrBatchDto } from './dto/qr-batch.dto';
import { newStickerCode, normalizeCode } from './sticker-code';
import { findSensitiveData } from '../common/text-safety';

/** 每位使用者最多同時綁定幾張貼紙，避免有人把整批貼紙一次綁走。 */
export const MAX_BOUND_PER_USER = 30;
const INSERT_CHUNK = 100;

export type StickerState = 'invalid' | 'unbound' | 'disabled' | 'revoked' | 'active';

@Injectable()
export class QrService {
  constructor(
    @InjectRepository(QrItem) private readonly qrRepo: Repository<QrItem>,
    @InjectRepository(QrBatch) private readonly batchRepo: Repository<QrBatch>,
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

  /** 撿到的人會看到物品名稱；聯絡一律走站內訊息，名稱裡不放電話或 email。 */
  private assertSafeName(name: string): void {
    const sensitive = findSensitiveData(name);
    if (sensitive) throw new BadRequestException(`物品名稱不能包含${sensitive}，撿到的人會透過站內訊息聯絡你`);
  }

  // ---- 管理員：印製與停用 ----

  async createBatch(dto: CreateQrBatchDto, admin: User): Promise<{ batch: QrBatch; codes: string[] }> {
    const codes = await this.freshCodes(dto.count);
    const batch = await this.batchRepo.save(
      this.batchRepo.create({
        label: dto.label.trim(),
        place: dto.place?.trim() || null,
        count: dto.count,
        createdBy: admin.id,
      }),
    );
    const base = this.baseUrl();
    for (let i = 0; i < codes.length; i += INSERT_CHUNK) {
      await this.qrRepo
        .createQueryBuilder()
        .insert()
        .into(QrItem)
        .values(
          codes.slice(i, i + INSERT_CHUNK).map((code) => ({
            code,
            qrCode: `${base}/qr/${code}`,
            batchId: batch.id,
            name: '',
            description: '',
            qrImageUrl: '',
          })),
        )
        .execute();
    }
    return { batch, codes };
  }

  private async freshCodes(count: number): Promise<string[]> {
    const codes = new Set<string>();
    while (codes.size < count) codes.add(newStickerCode());
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const taken = await this.qrRepo.find({ where: { code: In([...codes]) }, select: { code: true } });
      if (!taken.length) return [...codes];
      for (const row of taken) codes.delete(row.code as string);
      while (codes.size < count) codes.add(newStickerCode());
    }
    throw new ConflictException('產生貼紙編號失敗，請再試一次');
  }

  async listBatches(): Promise<Array<QrBatch & { bound: number; disabled: number }>> {
    const batches = await this.batchRepo.find({ order: { createdAt: 'DESC' }, take: 200 });
    if (!batches.length) return [];
    const rows = await this.qrRepo
      .createQueryBuilder('q')
      .select('q.batch_id', 'batchId')
      .addSelect('COUNT(q.bound_at)', 'bound')
      .addSelect('COUNT(q.disabled_at)', 'disabled')
      .where('q.batch_id IN (:...ids)', { ids: batches.map((b) => b.id) })
      .groupBy('q.batch_id')
      .getRawMany<{ batchId: string; bound: string; disabled: string }>();
    const stats = new Map(rows.map((r) => [r.batchId, r]));
    return batches.map((b) => ({
      ...b,
      bound: Number(stats.get(b.id)?.bound ?? 0),
      disabled: Number(stats.get(b.id)?.disabled ?? 0),
    }));
  }

  async batchCodes(batchId: string): Promise<{ batch: QrBatch; items: QrItem[] }> {
    const batch = await this.batchRepo.findOne({ where: { id: batchId } });
    if (!batch) throw new NotFoundException('找不到這個批次');
    const items = await this.qrRepo.find({ where: { batchId }, order: { code: 'ASC' } });
    return { batch, items };
  }

  /** 停用單張（code）或整批（batchId）。停用後不能綁定、也掃不到。 */
  async disable(target: { code?: string; batchId?: string }): Promise<number> {
    const now = new Date();
    if (target.batchId) {
      const res = await this.qrRepo.update({ batchId: target.batchId, disabledAt: IsNull() }, { disabledAt: now });
      return res.affected ?? 0;
    }
    const code = normalizeCode(target.code ?? '');
    if (!code) throw new BadRequestException('貼紙編號格式不正確');
    const res = await this.qrRepo.update({ code, disabledAt: IsNull() }, { disabledAt: now });
    if (!res.affected) throw new NotFoundException('找不到這張貼紙，或已經停用');
    return res.affected;
  }

  // ---- 使用者：綁定與管理 ----

  /**
   * 舊版 App 的「自己產生防丟牌」。新流程是綁定官方印的貼紙（bind）；新版 App 上架前先保留，
   * 已安裝舊版的使用者才不會一更新後端就不能建立防丟牌。產生的貼紙直接視為已綁定。
   */
  async generate(dto: GenerateQrDto, user: User): Promise<QrItem> {
    if (this.config.get<string>('QR_SELF_GENERATE', 'true') === 'false') {
      throw new GoneException('貼紙改由官方發放，請輸入貼紙上的編號綁定');
    }
    this.assertSafeName(dto.name);
    const code = randomUUID();
    return this.qrRepo.save(this.qrRepo.create({
      userId: user.id,
      name: dto.name,
      description: dto.description ?? '',
      code,
      qrCode: `${this.baseUrl()}/qr/${code}`,
      qrImageUrl: '',
      boundAt: new Date(),
    }));
  }

  async bind(dto: BindQrDto, user: User): Promise<QrItem> {
    const code = normalizeCode(dto.code);
    if (!code) throw new NotFoundException('找不到這個貼紙編號');
    this.assertSafeName(dto.name);
    const bound = await this.qrRepo.count({ where: { userId: user.id, revokedAt: IsNull() } });
    if (bound >= MAX_BOUND_PER_USER) {
      throw new ForbiddenException(`最多只能綁定 ${MAX_BOUND_PER_USER} 張貼紙`);
    }
    // 條件寫在 UPDATE 裡：兩個人同時綁同一張，只會有一個成功。
    const res = await this.qrRepo.update(
      { code, userId: IsNull(), disabledAt: IsNull(), revokedAt: IsNull() },
      { userId: user.id, name: dto.name.trim(), description: dto.description?.trim() ?? '', boundAt: new Date() },
    );
    if (!res.affected) {
      const state = this.stateOf(await this.qrRepo.findOne({ where: { code }, relations: { user: true } }));
      if (state === 'invalid') throw new NotFoundException('找不到這個貼紙編號');
      if (state === 'disabled' || state === 'revoked') throw new GoneException('這張貼紙已停用');
      throw new ConflictException('這張貼紙已經被綁定');
    }
    const item = await this.qrRepo.findOne({ where: { code } });
    if (!item) throw new NotFoundException('找不到這個貼紙編號');
    return item;
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
    const qrItem = await this.owned(id, user);
    if (dto.name !== undefined) {
      this.assertSafeName(dto.name);
      qrItem.name = dto.name.trim();
    }
    if (dto.description !== undefined) qrItem.description = dto.description.trim();
    return this.qrRepo.save(qrItem);
  }

  /**
   * 撤銷之後這張貼紙就永久失效（物主可能已把它弄丟或轉手），不會回到未綁定。
   * 重複刪除（例如連點兩次）視為成功。
   */
  async remove(id: string, user: User): Promise<void> {
    const qrItem = await this.qrRepo.findOne({ where: { id } });
    if (!qrItem) throw new NotFoundException('QR 物品不存在');
    if (qrItem.userId !== user.id) throw new ForbiddenException('無權限刪除此 QR');
    if (qrItem.revokedAt) return;
    qrItem.revokedAt = new Date();
    await this.qrRepo.save(qrItem);
  }

  private async owned(id: string, user: User): Promise<QrItem> {
    const qrItem = await this.qrRepo.findOne({ where: { id } });
    if (!qrItem || qrItem.revokedAt) throw new NotFoundException('QR 物品不存在');
    if (qrItem.userId !== user.id) throw new ForbiddenException('無權限修改此 QR');
    return qrItem;
  }

  // ---- 掃描 ----

  /** 只有已綁定、未停用、未撤銷、物主帳號正常的貼紙掃得到。 */
  async scanByCode(code: string): Promise<{ qrItem: QrItem; owner: User }> {
    const { state, qrItem } = await this.inspect(code);
    if (state === 'unbound') throw new NotFoundException('這張貼紙尚未啟用');
    // 停權的物主暫時聯絡不到（與帳號刪除不同，貼紙本身仍屬於他）。
    if (state !== 'active' || !qrItem?.user || qrItem.user.status !== 'active') {
      throw new NotFoundException('QR Code 無效或已失效');
    }
    return { qrItem, owner: qrItem.user };
  }

  /** 查貼紙現在的狀態，給掃描與說明頁分辨「尚未啟用」和「已失效」。 */
  async inspect(code: string): Promise<{ state: StickerState; qrItem: QrItem | null }> {
    const normalized = normalizeCode(code);
    if (!normalized) return { state: 'invalid', qrItem: null };
    const qrItem = await this.qrRepo
      .createQueryBuilder('qr')
      .leftJoinAndSelect('qr.user', 'user')
      .where('qr.code = :code OR qr.qr_code = :code OR qr.qr_code LIKE :suffix', {
        code: normalized,
        suffix: `%/${normalized}`,
      })
      .getOne();
    return { state: this.stateOf(qrItem), qrItem };
  }

  private stateOf(qrItem: QrItem | null): StickerState {
    if (!qrItem) return 'invalid';
    if (qrItem.disabledAt) return 'disabled';
    if (qrItem.revokedAt) return 'revoked';
    if (!qrItem.boundAt || !qrItem.userId) return 'unbound';
    if (qrItem.user?.status === 'deleted') return 'revoked';
    return 'active';
  }
}
