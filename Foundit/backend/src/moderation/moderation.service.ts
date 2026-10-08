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
import { CreateReportDto, ResolveReportDto } from './dto/moderation.dto';

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
