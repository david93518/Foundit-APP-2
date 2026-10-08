import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ModerationService } from './moderation.service';
import {
  AdminListQueryDto, ItemActionDto, ResolveReportDto, SuspendUserDto,
} from './dto/moderation.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';
import { AdminAction } from '../common/entities/admin-action.entity';
import { toMobileItem } from '../items/item-mobile.serializer';

/** 管理端的使用者形狀：不含 token、推播識別或 Google subject。 */
function toAdminUser(u: User): Record<string, unknown> {
  return {
    id: u.id,
    name: u.name ?? '',
    email: u.email ?? '',
    // Google 帳號的 phone 欄位存的是內部識別，不是手機號碼。
    phone: u.phone?.startsWith('09') ? u.phone : '',
    login: u.googleSub ? 'google' : 'phone',
    role: u.role,
    status: u.status,
    is_verified: u.isVerified ?? false,
    created_at: u.createdAt ? new Date(u.createdAt).getTime() : null,
  };
}

function toAdminItem(item: Item): Record<string, unknown> {
  return {
    ...toMobileItem(item),
    hidden_at: item.hiddenAt ? new Date(item.hiddenAt).getTime() : null,
    owner_email: item.user?.email ?? '',
    owner_status: item.user?.status ?? '',
  };
}

function toAdminAction(row: AdminAction): Record<string, unknown> {
  return {
    id: row.id,
    actor_id: row.actorId,
    action: row.action,
    target_type: row.targetType,
    target_id: row.targetId,
    reason: row.reason,
    result: row.result,
    created_at: row.createdAt ? new Date(row.createdAt).getTime() : null,
  };
}

@ApiTags('管理')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly moderation: ModerationService) {}

  @Get('me')
  @ApiOperation({ summary: '確認目前帳號具管理員權限（非管理員得到 403）' })
  me(@CurrentUser() admin: User) {
    return { success: true, data: toAdminUser(admin) };
  }

  @Get('users')
  @ApiOperation({ summary: '使用者清單（q／status／page／page_size）' })
  async users(@Query() query: AdminListQueryDto) {
    const { data, total } = await this.moderation.listUsers(query);
    return { success: true, total, data: data.map(toAdminUser) };
  }

  @Get('items')
  @ApiOperation({ summary: '物品清單，含已隱藏與已結案（q／status／hidden／page／page_size）' })
  async items(@Query() query: AdminListQueryDto) {
    const { data, total } = await this.moderation.listItems(query);
    return { success: true, total, data: data.map(toAdminItem) };
  }

  @Post('items/:id/hide')
  @ApiOperation({ summary: '下架物品' })
  async hideItem(
    @CurrentUser() admin: User,
    @Param('id') id: string,
    @Body() dto: ItemActionDto,
  ) {
    const item = await this.moderation.hideItem(admin, id, dto.reason);
    return { success: true, data: toAdminItem(item) };
  }

  @Post('items/:id/restore')
  @ApiOperation({ summary: '恢復物品' })
  async restoreItem(
    @CurrentUser() admin: User,
    @Param('id') id: string,
    @Body() dto: ItemActionDto,
  ) {
    const item = await this.moderation.restoreItem(admin, id, dto.reason);
    return { success: true, data: toAdminItem(item) };
  }

  @Get('actions')
  @ApiOperation({ summary: '最近 200 筆管理操作紀錄' })
  async actions() {
    const rows = await this.moderation.listActions();
    return { success: true, data: rows.map(toAdminAction) };
  }

  @Get('reports')
  async reports() {
    const data = await this.moderation.listReports();
    return {
      success: true,
      data: data.map((row) => ({
        id: row.id,
        reporter_id: row.reporterId,
        target_type: row.targetType,
        target_id: row.targetId,
        reason: row.reason,
        status: row.status,
        resolution: row.resolution,
        handled_by: row.handledBy,
        created_at: row.createdAt,
      })),
    };
  }

  @Post('reports/:id/resolve')
  async resolve(
    @CurrentUser() admin: User,
    @Param('id') id: string,
    @Body() dto: ResolveReportDto,
  ) {
    const report = await this.moderation.resolveReport(admin, id, dto);
    return { success: true, data: { id: report.id, status: report.status } };
  }

  @Post('users/:id/suspend')
  async suspend(
    @CurrentUser() admin: User,
    @Param('id') id: string,
    @Body() dto: SuspendUserDto,
  ) {
    await this.moderation.suspend(admin, id, dto.reason);
    return { success: true };
  }

  @Post('users/:id/restore')
  async restore(
    @CurrentUser() admin: User,
    @Param('id') id: string,
    @Body() dto: SuspendUserDto,
  ) {
    await this.moderation.restore(admin, id, dto.reason);
    return { success: true };
  }
}
