import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PointsService } from './points.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { toPublicProfile } from '../users/public-profile';

@ApiTags('積分')
@Controller()
export class PointsController {
  constructor(private readonly pointsService: PointsService) {}

  @Get('users/me/points')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '取得我的積分與歷史紀錄' })
  async getMyPoints(@CurrentUser() user: User) {
    const data = await this.pointsService.getPoints(user.id);
    return { success: true, ...data };
  }

  @Get('leaderboard')
  @ApiOperation({ summary: '積分排行榜' })
  async getLeaderboard() {
    const rows = await this.pointsService.getLeaderboard();
    return {
      success: true,
      data: rows.map((row) => ({
        points: row.points,
        user: row.user ? toPublicProfile(row.user) : null,
      })),
    };
  }
}
