import {
  Injectable, NotFoundException, ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, SelectQueryBuilder } from 'typeorm';
import { Item, ItemStatus, ItemType } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { CreateItemDto } from './dto/create-item.dto';
import { QueryItemDto } from './dto/query-item.dto';

@Injectable()
export class ItemsService {
  constructor(
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
  ) {}

  async findAll(query: QueryItemDto): Promise<{ data: Item[]; total: number; hasMore: boolean }> {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 50);

    const qb = this.itemRepo
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.user', 'user')
      .where('item.status = :status', { status: ItemStatus.ACTIVE });

    this.applyFilters(qb, query);

    qb.orderBy('item.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [data, total] = await qb.getManyAndCount();
    return { data, total, hasMore: page * pageSize < total };
  }

  async findOne(id: string): Promise<Item> {
    const item = await this.itemRepo.findOne({
      where: { id },
      relations: ['user'],
    });
    if (!item) throw new NotFoundException('物品不存在');
    return item;
  }

  async create(dto: CreateItemDto, user: User): Promise<Item> {
    const item = this.itemRepo.create({
      ...dto,
      userId: user.id,
      images: dto.images ?? [],
      lostAt: dto.lostAt ? new Date(dto.lostAt) : new Date(),
    });
    const saved = await this.itemRepo.save(item);
    saved.user = user;
    return saved;
  }

  async update(id: string, dto: Partial<CreateItemDto>, user: User): Promise<Item> {
    const item = await this.findOne(id);
    if (item.userId !== user.id) throw new ForbiddenException('無權限修改此物品');

    const { lostAt, ...rest } = dto;
    const updateData: Partial<Item> = { ...rest };
    if (lostAt) updateData.lostAt = new Date(lostAt);

    Object.assign(item, updateData);
    return this.itemRepo.save(item);
  }

  async remove(id: string, user: User): Promise<void> {
    const item = await this.findOne(id);
    if (item.userId !== user.id) throw new ForbiddenException('無權限刪除此物品');
    await this.itemRepo.remove(item);
  }

  async resolve(id: string, user: User): Promise<void> {
    const item = await this.findOne(id);
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
  async findForMatch(excludeItemId: string, keywords: string[]): Promise<Item[]> {
    const qb = this.itemRepo
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.user', 'user')
      .where('item.status = :status', { status: ItemStatus.ACTIVE })
      .andWhere('item.id != :id', { id: excludeItemId });

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
    if (query.keyword) {
      qb.andWhere(
        '(item.title ILIKE :kw OR item.description ILIKE :kw)',
        { kw: `%${query.keyword}%` },
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
