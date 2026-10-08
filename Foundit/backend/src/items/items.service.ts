import {
  BadRequestException, ForbiddenException, Injectable, NotFoundException, Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, SelectQueryBuilder } from 'typeorm';
import { Item, ItemStatus, ItemType } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { Chat } from '../common/entities/chat.entity';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { QueryItemDto } from './dto/query-item.dto';
import { normalizeCoordinates } from './coordinates';
import { isUuid } from '../common/ids';

@Injectable()
export class ItemsService {
  constructor(
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
    @Optional() @InjectRepository(User) private readonly userRepo?: Repository<User>,
  ) {}

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
    const visible = item.status === ItemStatus.ACTIVE && !item.hiddenAt;
    if (!visible && item.userId !== viewerId) throw new NotFoundException('物品不存在');
    return item;
  }

  async create(dto: CreateItemDto, user: User): Promise<Item> {
    if (user.status !== 'active') throw new ForbiddenException('帳號無法刊登');
    if (dto.termsAccepted !== true || !dto.termsVersion?.trim()) {
      throw new BadRequestException('請先同意刊登規範');
    }
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

    if (dto.title !== undefined) item.title = dto.title.trim();
    if (dto.category !== undefined) item.category = dto.category.trim();
    if (dto.description !== undefined) item.description = dto.description.trim();
    if (dto.color !== undefined) item.color = dto.color.trim();
    if (dto.images !== undefined) item.images = dto.images.slice(0, 6);
    if (dto.locationName !== undefined) item.locationName = dto.locationName.trim();
    if (dto.reward !== undefined) item.reward = dto.reward;
    if (dto.hasReward !== undefined) item.hasReward = dto.hasReward;
    if (dto.storageLocation !== undefined) item.storageLocation = dto.storageLocation.trim();
    if (dto.handedToPolice !== undefined) item.handedToPolice = dto.handedToPolice;
    if (dto.lostAt !== undefined) item.lostAt = new Date(dto.lostAt);
    if (dto.latitude !== undefined || dto.longitude !== undefined) {
      const coords = normalizeCoordinates(
        dto.latitude ?? (item.latitude == null ? null : Number(item.latitude)),
        dto.longitude ?? (item.longitude == null ? null : Number(item.longitude)),
      );
      item.latitude = coords?.latitude ?? null;
      item.longitude = coords?.longitude ?? null;
    }
    return this.itemRepo.save(item);
  }

  async remove(id: string, user: User): Promise<void> {
    if (!isUuid(id)) throw new NotFoundException('物品不存在');
    const item = await this.itemRepo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('物品不存在');
    if (item.userId !== user.id) throw new ForbiddenException('無權限刪除此物品');
    const chatCount = await this.itemRepo.manager.getRepository(Chat).count({ where: { itemId: id } });
    if (chatCount > 0) {
      item.status = ItemStatus.CLOSED;
      item.hiddenAt = new Date();
      await this.itemRepo.save(item);
      return;
    }
    await this.itemRepo.remove(item);
  }

  async resolve(id: string, user: User): Promise<void> {
    const item = await this.findOne(id, user.id);
    if (item.userId !== user.id) throw new ForbiddenException('無權限操作此物品');
    item.status = ItemStatus.RESOLVED;
    await this.itemRepo.save(item);
  }

  async findByUser(userId: string): Promise<Item[]> {
    return this.itemRepo.find({
      where: { userId },
      relations: ['user'],
      order: { createdAt: 'DESC' },
    });
  }

  /** 我的物品總數（已登記） */
  async countByUser(userId: string): Promise<number> {
    return this.itemRepo.count({ where: { userId } });
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
  async getStats(): Promise<{
    total_active: number;
    total_resolved: number;
    total_lost: number;
    total_found: number;
    by_category: Record<string, number>;
  }> {
    // 平行執行三個聚合查詢，效能最佳
    const [statusRows, typeRows, categoryRows] = await Promise.all([
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.status', 'status')
        .addSelect('COUNT(*)', 'count')
        .groupBy('item.status')
        .getRawMany<{ status: string; count: string }>(),
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.type', 'type')
        .addSelect('COUNT(*)', 'count')
        .where('item.status = :status', { status: ItemStatus.ACTIVE })
        .groupBy('item.type')
        .getRawMany<{ type: string; count: string }>(),
      this.itemRepo
        .createQueryBuilder('item')
        .select('item.category', 'category')
        .addSelect('COUNT(*)', 'count')
        .where('item.status = :status', { status: ItemStatus.ACTIVE })
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
      keywords.forEach((kw, i) => (params[`kw${i}`] = `%${kw}%`));
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
        { kw: `%${kw}%` },
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
    // 地理範圍搜尋（使用 Haversine 公式，單位：km）
    if (query.lat && query.lng && query.radius) {
      qb.andWhere(
        `(6371 * acos(cos(radians(:lat)) * cos(radians(CAST(item.latitude AS FLOAT))) * cos(radians(CAST(item.longitude AS FLOAT)) - radians(:lng)) + sin(radians(:lat)) * sin(radians(CAST(item.latitude AS FLOAT))))) < :radius`,
        { lat: query.lat, lng: query.lng, radius: query.radius },
      );
    }
  }
}
