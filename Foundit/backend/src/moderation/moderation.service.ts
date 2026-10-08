import {
  BadRequestException, ForbiddenException, Injectable, NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
    if (dto.targetType !== 'user' && !isUuid(dto.targetId)) {
      throw new BadRequestException('檢舉對象不正確');
    }
    if (dto.targetType === 'user' && dto.targetId === reporter.id) {
      throw new BadRequestException('不能檢舉自己');
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
    await this.blocks.save(this.blocks.create({ blockerId: blocker.id, blockedId }));
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.blocks.delete({ blockerId, blockedId });
  }

  listBlocks(blockerId: string): Promise<Block[]> {
    return this.blocks.find({ where: { blockerId }, order: { createdAt: 'DESC' } });
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
    if (query.status) qb.andWhere('item.status = :status', { status: query.status.toUpperCase() });
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
