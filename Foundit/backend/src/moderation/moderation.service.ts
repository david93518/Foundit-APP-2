import {
  BadRequestException, ForbiddenException, Injectable, NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Report } from '../common/entities/report.entity';
import { Block } from '../common/entities/block.entity';
import { AdminAction } from '../common/entities/admin-action.entity';
import { User } from '../common/entities/user.entity';
import { Item, ItemStatus } from '../common/entities/item.entity';
import { ChatsGateway } from '../chats/chats.gateway';
import { isUuid } from '../common/ids';
import { AdminListQueryDto, CreateReportDto, ResolveReportDto } from './dto/moderation.dto';

function paging(query: AdminListQueryDto): { page: number; pageSize: number } {
  const page = Math.max(1, query.page ?? 1);
  const pageSize = Math.min(100, Math.max(1, query.page_size ?? 20));
  return { page, pageSize };
}

@Injectable()
export class ModerationService {
  constructor(
    @InjectRepository(Report) private readonly reports: Repository<Report>,
    @InjectRepository(Block) private readonly blocks: Repository<Block>,
    @InjectRepository(AdminAction) private readonly actions: Repository<AdminAction>,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Item) private readonly items: Repository<Item>,
    private readonly gateway: ChatsGateway,
  ) {}

  async report(reporter: User, dto: CreateReportDto): Promise<Report> {
    if (reporter.status !== 'active') throw new ForbiddenException('帳號無法檢舉');
    if (!isUuid(dto.targetId)) {
      throw new BadRequestException('檢舉對象不正確');
    }
    if (dto.targetType === 'user' && dto.targetId === reporter.id) {
      throw new BadRequestException('不能檢舉自己');
    }
    if (dto.targetType === 'user' && !await this.users.findOne({ where: { id: dto.targetId } })) {
      throw new NotFoundException('使用者不存在');
    }
    return this.reports.save(this.reports.create({
      reporterId: reporter.id,
      targetType: dto.targetType,
      targetId: dto.targetId,
      reason: dto.reason.trim(),
      status: 'open',
    }));
  }

  async block(blocker: User, blockedId: string): Promise<void> {
    if (!isUuid(blockedId) || blockedId === blocker.id) {
      throw new BadRequestException('封鎖對象不正確');
    }
    const target = await this.users.findOne({ where: { id: blockedId } });
    if (!target) throw new NotFoundException('使用者不存在');
    const existing = await this.blocks.findOne({ where: { blockerId: blocker.id, blockedId } });
    if (existing) return;
    await this.blocks.upsert({ blockerId: blocker.id, blockedId }, ['blockerId', 'blockedId']);
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    if (!isUuid(blockedId)) throw new BadRequestException('封鎖對象不正確');
    await this.blocks.delete({ blockerId, blockedId });
  }

  listBlocks(blockerId: string): Promise<Block[]> {
    return this.blocks.find({ where: { blockerId }, order: { createdAt: 'DESC' } });
  }

  async blockSummaries(blockerId: string) {
    const rows = await this.listBlocks(blockerId);
    if (!rows.length) return [];
    const users = await this.users.find({ where: {id: In(rows.map(row => row.blockedId))}, select: ['id', 'name', 'avatarUrl', 'status'] });
    const people = new Map(users.map(user => [user.id, user]));
    return rows.map(row => {
      const user = people.get(row.blockedId);
      const available = user && user.status !== 'deleted';
      return {user_id: row.blockedId, name: available ? user.name : '已刪除的帳號',
        avatar_url: available ? user.avatarUrl : '', created_at: row.createdAt};
    });
  }

  listReports(): Promise<Report[]> {
    return this.reports.find({ order: { createdAt: 'DESC' }, take: 100 });
  }

  async resolveReport(admin: User, reportId: string, dto: ResolveReportDto): Promise<Report> {
    const report = await this.reports.findOne({ where: { id: reportId } });
    if (!report) throw new NotFoundException('檢舉不存在');
    if (dto.action === 'hide' && report.targetType === 'item' && isUuid(report.targetId)) {
      await this.items.update(report.targetId, { status: ItemStatus.CLOSED, hiddenAt: new Date() });
      report.status = 'hidden';
    } else if (dto.action === 'suspend' && report.targetType === 'user' && isUuid(report.targetId)) {
      await this.suspend(admin, report.targetId, dto.reason);
      report.status = 'suspended';
    } else if (dto.action === 'dismiss') {
      report.status = 'dismissed';
    } else {
      throw new BadRequestException('這個處置不適用於檢舉對象');
    }
    report.resolution = dto.reason.trim();
    report.handledBy = admin.id;
    const saved = await this.reports.save(report);
    await this.audit(admin.id, `report.${dto.action}`, report.targetType, report.targetId, dto.reason, report.status);
    return saved;
  }

  async suspend(admin: User, userId: string, reason: string): Promise<void> {
    if (userId === admin.id) throw new BadRequestException('不能停用自己的帳號');
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('使用者不存在');
    // 管理員之間不能互相停權：一組被盜的管理員帳號不該能把其他管理員全部踢掉。
    if (user.role === 'admin') throw new ForbiddenException('不能停用其他管理員，請直接在資料庫處理');
    user.status = 'suspended';
    user.tokenVersion += 1;
    user.fcmToken = null;
    await this.users.save(user);
    this.gateway.disconnectUser(userId);
    await this.audit(admin.id, 'user.suspend', 'user', userId, reason, 'suspended');
  }

  async restore(admin: User, userId: string, reason: string): Promise<void> {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status === 'deleted') throw new NotFoundException('使用者不存在');
    user.status = 'active';
    user.tokenVersion += 1;
    await this.users.save(user);
    this.gateway.disconnectUser(userId);
    await this.audit(admin.id, 'user.restore', 'user', userId, reason, 'active');
  }

  /** 管理端使用者清單：可用名稱／email／手機關鍵字與狀態篩選。 */
  async listUsers(query: AdminListQueryDto): Promise<{ data: User[]; total: number }> {
    const { page, pageSize } = paging(query);
    const qb = this.users
      .createQueryBuilder('user')
      .orderBy('user.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);
    const q = query.q?.trim();
    if (q) {
      qb.andWhere('(user.name ILIKE :q OR user.email ILIKE :q OR user.phone ILIKE :q)', { q: `%${q}%` });
    }
    if (query.status) qb.andWhere('user.status = :status', { status: query.status.toLowerCase() });
    const [data, total] = await qb.getManyAndCount();
    return { data, total };
  }

  /** 管理端物品清單：和公開列表不同，已隱藏與已結案的也看得到。 */
  async listItems(query: AdminListQueryDto): Promise<{ data: Item[]; total: number }> {
    const { page, pageSize } = paging(query);
    const qb = this.items
      .createQueryBuilder('item')
      .leftJoinAndSelect('item.user', 'user')
      .orderBy('item.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);
    const q = query.q?.trim();
    if (q) {
      qb.andWhere('(item.title ILIKE :q OR item.description ILIKE :q OR item.locationName ILIKE :q)', { q: `%${q}%` });
    }
    if (query.status) {
      const status = query.status.toUpperCase() as ItemStatus;
      if (!Object.values(ItemStatus).includes(status)) throw new BadRequestException('物品狀態不正確');
      qb.andWhere('item.status = :status', { status });
    }
    if (query.hidden === 'true') qb.andWhere('item.hiddenAt IS NOT NULL');
    if (query.hidden === 'false') qb.andWhere('item.hiddenAt IS NULL');
    const [data, total] = await qb.getManyAndCount();
    return { data, total };
  }

  /** 下架：從公開列表、地圖與詳情頁消失，刊登者本人仍看得到。 */
  async hideItem(admin: User, itemId: string, reason: string): Promise<Item> {
    const item = await this.findItem(itemId);
    item.status = ItemStatus.CLOSED;
    item.hiddenAt = new Date();
    const saved = await this.items.save(item);
    await this.audit(admin.id, 'item.hide', 'item', itemId, reason, 'hidden');
    return saved;
  }

  async restoreItem(admin: User, itemId: string, reason: string): Promise<Item> {
    const item = await this.findItem(itemId);
    // 只能恢復「被管理端下架」的刊登。刊登者自己刪除、或帳號已刪除的內容，管理員不能替對方重新公開。
    const owner = await this.users.findOne({ where: { id: item.userId } });
    if (!owner || owner.status === 'deleted') {
      throw new BadRequestException('刊登者已刪除帳號，這則刊登不能恢復');
    }
    const hiddenByModeration = await this.actions.findOne({
      where: { targetType: 'item', targetId: itemId, action: In(['item.hide', 'report.hide']) },
      order: { createdAt: 'DESC' },
    });
    if (!hiddenByModeration) {
      throw new BadRequestException('這則刊登是刊登者自己移除的，管理端不能重新公開');
    }
    item.status = ItemStatus.ACTIVE;
    item.hiddenAt = null;
    const saved = await this.items.save(item);
    await this.audit(admin.id, 'item.restore', 'item', itemId, reason, 'active');
    return saved;
  }

  /** 稽核紀錄只追加；這裡回傳最近 200 筆供後台檢視。 */
  listActions(): Promise<AdminAction[]> {
    return this.actions.find({ order: { createdAt: 'DESC' }, take: 200 });
  }

  private async findItem(itemId: string): Promise<Item> {
    if (!isUuid(itemId)) throw new NotFoundException('物品不存在');
    const item = await this.items.findOne({ where: { id: itemId } });
    if (!item) throw new NotFoundException('物品不存在');
    return item;
  }

  private audit(
    actorId: string,
    action: string,
    targetType: string,
    targetId: string,
    reason: string,
    result: string,
  ): Promise<AdminAction> {
    return this.actions.save(this.actions.create({
      actorId,
      action,
      targetType,
      targetId,
      reason: reason.trim(),
      result,
    }));
  }
}
