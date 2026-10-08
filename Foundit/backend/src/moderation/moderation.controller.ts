import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ModerationService } from './moderation.service';
import { BlockUserDto, CreateReportDto } from './dto/moderation.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';

@ApiTags('檢舉與封鎖')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Post('reports')
  async report(@CurrentUser() user: User, @Body() dto: CreateReportDto) {
    const data = await this.moderation.report(user, dto);
    return { success: true, data: { id: data.id, status: data.status } };
  }

  @Post('blocks')
  async block(@CurrentUser() user: User, @Body() dto: BlockUserDto) {
    await this.moderation.block(user, dto.userId);
    return { success: true };
  }

  @Delete('blocks/:userId')
  async unblock(@CurrentUser() user: User, @Param('userId') userId: string) {
    await this.moderation.unblock(user.id, userId);
    return { success: true };
  }

  @Get('blocks')
  async list(@CurrentUser() user: User) {
    const rows = await this.moderation.listBlocks(user.id);
    return { success: true, data: rows.map((row) => ({ user_id: row.blockedId, created_at: row.createdAt })) };
  }
}
