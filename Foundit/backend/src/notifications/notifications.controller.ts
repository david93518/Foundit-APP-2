import { Controller, Get, Patch, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { toMobileNotification } from './notification-mobile.serializer';

@ApiTags('通知')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: '取得通知列表' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'offset', required: false, type: Number })
  async findAll(
    @CurrentUser() user: User,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const take = Math.min(Math.max(parseInt(limit ?? '50', 10) || 50, 1), 100);
    const skip = Math.max(parseInt(offset ?? '0', 10) || 0, 0);
    const data = await this.notifService.findAllByUser(user.id, take, skip);
    return { success: true, data: data.map(toMobileNotification) };
  }

  @Get('unread-count')
  @ApiOperation({ summary: '取得未讀通知數' })
  async unreadCount(@CurrentUser() user: User) {
    const count = await this.notifService.unreadCountForUser(user.id);
    return { success: true, data: { count } };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: '標記單一通知已讀' })
  async markRead(@Param('id') id: string, @CurrentUser() user: User) {
    await this.notifService.markRead(id, user.id);
    return { success: true };
  }

  @Patch('read-all')
  @ApiOperation({ summary: '全部標記已讀' })
  async markAllRead(@CurrentUser() user: User) {
    await this.notifService.markAllRead(user.id);
    return { success: true };
  }
}
