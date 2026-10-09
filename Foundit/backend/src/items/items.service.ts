import {
  BadRequestException, ForbiddenException, Injectable, NotFoundException, Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { IsNull, Repository, SelectQueryBuilder } from 'typeorm';
import { Item, ItemStatus, ItemType } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { QueryItemDto } from './dto/query-item.dto';
import { normalizeCoordinates } from './coordinates';
import { isUuid } from '../common/ids';
import { isOwnUpload, publicBaseUrl, uploadSecret } from '../common/media-url';
import { findSensitiveData } from '../common/text-safety';

/** ILIKE 會把 % 與 _ 當萬用字元；使用者輸入一律當成字面文字搜尋。 */
export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

type ItemStats = {
  total_active: number;
  total_resolved: number;
  total_lost: number;
  total_found: number;
  by_category: Record<string, number>;
};

@Injectable()
export class ItemsService {
  constructor(
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
    @Optional() @InjectRepository(User) private readonly userRepo?: Repository<User>,
    @Optional() private readonly config?: ConfigService,
  ) {}

  private statsCache: { expires: number; value: Promise<ItemStats> } | null = null;

  /** 公開刊登不能含手機、email、身分證或卡號；需要時請在私訊中提供給對方核對。 */
  private assertNoSensitiveData(...values: Array<string | undefined>): void {
    const kind = findSensitiveData(...values);
    if (kind) {
      throw new BadRequestException(`刊登內容疑似包含${kind}，請移除後再送出（需要時可在私訊提供給對方核對）`);
    }
  }

  /** 刊登照片只能是本人上傳到本站的圖片；編輯時原本就掛在這筆刊登上的照片可以保留。 */
  private assertImages(images: string[] | undefined, userId: string, existing: string[] = []): void {
    if (!images?.length) return;
    const base = publicBaseUrl(this.config);
    const secret = uploadSecret(this.config);
    const kept = new Set(existing);
    if (!images.every((url) => kept.has(url) || isOwnUpload(url, userId, base, secret))) {
      throw new BadRequestException('照片必須是上傳到 FOUND !T 的圖片');
    }
  }

  async findAll(query: QueryItemDto): Promise<{ data: Item[]; total: number; hasMore: boolean }> {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 50);

    const qb = this.itemRepo
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.user', 'user')
      .where('item.status = :status', { status: ItemStatus.ACTIVE })
      .andWhere('item.hidden_at IS NULL');

    this.applyFilters(qb, query);

    qb.orderBy('item.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [data, total] = await qb.getManyAndCount();
    return { data, total, hasMore: page * pageSize < total };
  }

  async findOne(id: string, viewerId?: string | null): Promise<Item> {
    // 非 uuid 直接當作不存在，避免 Postgres 型別錯誤變成 500。
    if (!isUuid(id)) throw new NotFoundException('物品不存在');
    const item = await this.itemRepo.findOne({
      where: { id },
      relations: ['user'],
    });
    if (!item) throw new NotFoundException('物品不存在');
    if (item.hiddenAt) throw new NotFoundException('刊登已移除');
    const visible = item.status === ItemStatus.ACTIVE && !item.hiddenAt;
    if (!visible && item.userId !== viewerId) throw new NotFoundException('物品不存在');
    return item;
  }

  async create(dto: CreateItemDto, user: User): Promise<Item> {
    if (user.status !== 'active') throw new ForbiddenException('帳號無法刊登');
    if (dto.termsAccepted !== true || !dto.termsVersion?.trim()) {
      throw new BadRequestException('請先同意刊登規範');
    }
    this.assertImages(dto.images, user.id);
    this.assertNoSensitiveData(dto.title, dto.description, dto.locationName, dto.storageLocation);
    if (this.userRepo) {
      await this.userRepo.update(user.id, { termsVersion: dto.termsVersion.trim() });
    }
    const coords = normalizeCoordinates(dto.latitude, dto.longitude);
    const item = this.itemRepo.create({
      type: dto.type,
      userId: user.id,
      title: dto.title.trim(),
      category: dto.category.trim(),
      description: dto.description?.trim() ?? '',
      color: dto.color?.trim() ?? '',
      images: (dto.images ?? []).slice(0, 6),
      latitude: coords?.latitude ?? null,
      longitude: coords?.longitude ?? null,
      locationName: dto.locationName?.trim() ?? '',
      lostAt: dto.lostAt ? new Date(dto.lostAt) : new Date(),
      reward: dto.reward ?? 0,
      hasReward: dto.hasReward ?? false,
      storageLocation: dto.storageLocation?.trim() ?? '',
      handedToPolice: dto.handedToPolice ?? false,
      status: ItemStatus.ACTIVE,
    });
    const saved = await this.itemRepo.save(item);
    saved.user = user;
    return saved;
  }

  async update(id: string, dto: UpdateItemDto, user: User): Promise<Item> {
    if (!isUuid(id)) throw new NotFoundException('物品不存在');
    const item = await this.itemRepo.findOne({ where: { id }, relations: ['user'] });
    if (!item) throw new NotFoundException('物品不存在');
    if (item.userId !== user.id) throw new ForbiddenException('無權限修改此物品');
    if (item.hiddenAt || item.status !== ItemStatus.ACTIVE) throw new BadRequestException('此刊登已結束，無法編輯');
    this.assertImages(dto.images, user.id, item.images ?? []);
    this.assertNoSensitiveData(dto.title, dto.description, dto.locationName, dto.storageLocation);

    const changes: Partial<Item> = {};
    if (dto.title !== undefined) changes.title = dto.title.trim();
    if (dto.category !== undefined) changes.category = dto.category.trim();
    if (dto.description !== undefined) changes.description = dto.description.trim();
    if (dto.color !== undefined) changes.color = dto.color.trim();
    if (dto.images !== undefined) changes.images = dto.images.slice(0, 6);
    if (dto.locationName !== undefined) changes.locationName = dto.locationName.trim();
    if (dto.reward !== undefined) changes.reward = dto.reward;
    if (dto.hasReward !== undefined) changes.hasReward = dto.hasReward;
    if (dto.storageLocation !== undefined) changes.storageLocation = dto.storageLocation.trim();
    if (dto.handedToPolice !== undefined) changes.handedToPolice = dto.handedToPolice;
    if (dto.lostAt !== undefined) changes.lostAt = new Date(dto.lostAt);
    if (dto.latitude !== undefined || dto.longitude !== undefined) {
      const coords = normalizeCoordinates(
        dto.latitude ?? (changes.latitude == null ? null : Number(item.latitude)),
        dto.longitude ?? (changes.longitude == null ? null : Number(item.longitude)),
      );
      changes.latitude = coords?.latitude ?? null;
      changes.longitude = coords?.longitude ?? null;
    }
    const result = await this.itemRepo.update(
      { id, userId: user.id, status: ItemStatus.ACTIVE, hiddenAt: IsNull() }, changes,
    );
    if (result.affected !== 1) throw new BadRequestException('此刊登已變更，請重新載入');
    return Object.assign(item, changes);
  }

  async remove(id: string, user: User): Promise<void> {
    if (!isUuid(id)) throw new NotFoundException('物品不存在');
    const item = await this.itemRepo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('物品不存在');
    if (item.userId !== user.id) throw new ForbiddenException('無權限刪除此物品');
    // Keep stable foreign keys for existing/concurrent chats. A removed listing
    // cannot be read or edited, and is excluded from the owner's collection.
    item.status = ItemStatus.CLOSED;
    item.hiddenAt = item.hiddenAt ?? new Date();
    await this.itemRepo.update({ id, userId: user.id }, { status: item.status, hiddenAt: item.hiddenAt });
  }

  async resolve(id: string, user: User): Promise<void> {
    const item = await this.findOne(id, user.id);
    if (item.userId !== user.id) throw new ForbiddenException('無權限操作此物品');
    if (item.status === ItemStatus.RESOLVED) return;
    const result = await this.itemRepo.update(
      { id, userId: user.id, status: ItemStatus.ACTIVE, hiddenAt: IsNull() },
      { status: ItemStatus.RESOLVED },
    );
    if (result.affected !== 1) throw new BadRequestException('此刊登已結束');
  }

  async findByUser(userId: string): Promise<Item[]> {
    return this.itemRepo.find({
      where: { userId, hiddenAt: IsNull() },
      relations: ['user'],
      order: { createdAt: 'DESC' },
    });
  }

  /** 我的物品總數（已登記） */
  async countByUser(userId: string): Promise<number> {
    return this.itemRepo.count({ where: { userId, hiddenAt: IsNull() } });
  }

  /** 我「成功幫助」的次數 = 我發過且 status=RESOLVED 的物品數 */
  async countResolvedByUser(userId: string): Promise<number> {
    return this.itemRepo.count({
      where: { userId, status: ItemStatus.RESOLVED },
    });
  }

  /** 依 type+user 統計，給 badges 計算用 */
  async countByUserAndType(userId: string, type: ItemType): Promise<number> {
    return this.itemRepo.count({ where: { userId, type } });
  }

  /**
   * 全平台統計（首頁社群榮譽帶 / 分類角標）。
   * 一次性 SQL 聚合，不再依賴前端 page-1 計數。
   */
  async getStats(): Promise<ItemStats> {
    // 首頁每次開啟都會呼叫；短暫快取，避免被反覆呼叫時每次都對整張表做三次彙總。
    const now = Date.now();
    if (!this.statsCache || this.statsCache.expires <= now) {
      const value = this.computeStats();
      this.statsCache = { expires: now + 30_000, value };
      value.catch(() => { this.statsCache = null; });
    }
    return this.statsCache.value;
  }

  private async computeStats(): Promise<ItemStats> {
    // 平行執行三個聚合查詢；已下架（hidden）的刊登不列入公開統計。
    const [statusRows, typeRows, categoryRows] = await Promise.all([
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.status', 'status')
        .addSelect('COUNT(*)', 'count')
        .where('item.hidden_at IS NULL')
        .groupBy('item.status')
        .getRawMany<{ status: string; count: string }>(),
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.type', 'type')
        .addSelect('COUNT(*)', 'count')
        .where('item.status = :status', { status: ItemStatus.ACTIVE })
        .andWhere('item.hidden_at IS NULL')
        .groupBy('item.type')
        .getRawMany<{ type: string; count: string }>(),
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.category', 'category')
        .addSelect('COUNT(*)', 'count')
        .where('item.status = :status', { status: ItemStatus.ACTIVE })
        .andWhere('item.hidden_at IS NULL')
        .groupBy('item.category')
        .getRawMany<{ category: string; count: string }>(),
    ]);

    const statusMap = Object.fromEntries(
      statusRows.map((r) => [r.status, Number(r.count)]),
    );
    const typeMap = Object.fromEntries(
      typeRows.map((r) => [r.type, Number(r.count)]),
    );
    const byCategory: Record<string, number> = {};
    for (const r of categoryRows) {
      byCategory[r.category] = Number(r.count);
    }

    return {
      total_active: statusMap[ItemStatus.ACTIVE] ?? 0,
      total_resolved: statusMap[ItemStatus.RESOLVED] ?? 0,
      total_lost: typeMap['LOST'] ?? 0,
      total_found: typeMap['FOUND'] ?? 0,
      by_category: byCategory,
    };
  }

  /** 供 AI 配對使用 */
  async findForMatch(excludeItemId: string | null, keywords: string[]): Promise<Item[]> {
    const qb = this.itemRepo
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.user', 'user')
      .where('item.status = :status', { status: ItemStatus.ACTIVE })
      .andWhere('item.hidden_at IS NULL');
    // 只有指定來源物品時才排除它；過去傳入 '__none__' 會讓 uuid 比對直接 500。
    if (excludeItemId) qb.andWhere('item.id != :id', { id: excludeItemId });

    if (keywords.length > 0) {
      const conditions = keywords.map((_, i) => `(item.title ILIKE :kw${i} OR item.description ILIKE :kw${i})`);
      const params: Record<string, string> = {};
      keywords.forEach((kw, i) => (params[`kw${i}`] = `%${escapeLike(kw)}%`));
      qb.andWhere(`(${conditions.join(' OR ')})`, params);
    }

    return qb.limit(10).getMany();
  }

  private applyFilters(qb: SelectQueryBuilder<Item>, query: QueryItemDto): void {
    if (query.type) {
      qb.andWhere('item.type = :type', { type: query.type });
    }
    if (query.category) {
      qb.andWhere('item.category = :category', { category: query.category });
    }
    const area = query.area?.trim().replace(/臺/g, '台');
    if (area && area !== '全部地區') {
      // Existing records store the city in location_name, sometimes as 臺北/臺中.
      // STRPOS treats the selected area literally, including any % or _ characters.
      qb.andWhere(`STRPOS(REPLACE("item"."location_name", '臺', '台'), :area) > 0`, {
        area,
      });
    }
    if (query.keyword?.trim()) {
      const kw = query.keyword.trim().replace(/臺/g, '台');
      qb.andWhere(
        `(REPLACE("item"."title", '臺', '台') ILIKE :kw OR REPLACE("item"."description", '臺', '台') ILIKE :kw OR REPLACE("item"."location_name", '臺', '台') ILIKE :kw OR REPLACE("item"."category", '臺', '台') ILIKE :kw)`,
        { kw: `%${escapeLike(kw)}%` },
      );
    }
    if (query.has_reward) {
      qb.andWhere('item.has_reward = true');
    }
    if (query.date_from) {
      qb.andWhere('item.lost_at >= :dateFrom', { dateFrom: new Date(query.date_from) });
    }
    if (query.date_to) {
      qb.andWhere('item.lost_at <= :dateTo', { dateTo: new Date(query.date_to) });
    }
    // 地理範圍搜尋（使用 Haversine 公式，單位：km）。浮點誤差可能讓 acos 的參數略大於 1，
    // Postgres 會直接報錯變成 500，所以先夾在 [-1, 1]。
    if (query.lat != null && query.lng != null && query.radius) {
      qb.andWhere(
        `(6371 * acos(LEAST(1, GREATEST(-1, cos(radians(:lat)) * cos(radians(CAST(item.latitude AS FLOAT))) * cos(radians(CAST(item.longitude AS FLOAT)) - radians(:lng)) + sin(radians(:lat)) * sin(radians(CAST(item.latitude AS FLOAT))))))) < :radius`,
        { lat: query.lat, lng: query.lng, radius: query.radius },
      );
    }
  }
}
