import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ModerationService } from './moderation.service';
import { BlockUserDto, CreateReportDto } from './dto/moderation.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';

@ApiTags('檢舉與封鎖')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class ModerationController {
  constructor(private readonly moderation: ModerationService) {}

  @Post('reports')
  @RateLimit({ name: 'report', limit: 20, windowMs: 60 * 60_000, by: 'user' })
  async report(@CurrentUser() user: User, @Body() dto: CreateReportDto) {
    const data = await this.moderation.report(user, dto);
    return { success: true, data: { id: data.id, status: data.status } };
  }

  @Post('blocks')
  @RateLimit({ name: 'block', limit: 60, windowMs: 60 * 60_000, by: 'user' })
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
    return { success: true, data: await this.moderation.blockSummaries(user.id) };
  }
}
