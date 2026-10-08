import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ModerationService } from './moderation.service';
import { ResolveReportDto, SuspendUserDto } from './dto/moderation.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';

@ApiTags('管理')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly moderation: ModerationService) {}

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
