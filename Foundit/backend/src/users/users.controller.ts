import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { IsString, IsOptional, MaxLength, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { toMobileItem } from '../items/item-mobile.serializer';
import { toMobileUser } from './user-mobile.serializer';

class UpdateProfileDto {
  @ApiProperty({ example: '小明', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  avatar_url?: string;

  @ApiProperty({ example: '台北生活家，喜歡探險', required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsEmail({}, { message: 'Email 格式不正確' })
  email?: string;
}

@ApiTags('用戶')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: '取得目前登入用戶資料' })
  async getMe(@CurrentUser() user: User) {
    const data = await this.usersService.getMe(user.id);
    return { success: true, data: toMobileUser(data) };
  }

  @Patch('me')
  @ApiOperation({ summary: '更新個人資料（name / avatar_url / bio / email）' })
  async updateProfile(@Body() dto: UpdateProfileDto, @CurrentUser() user: User) {
    const data = await this.usersService.updateProfile(user.id, {
      name: dto.name,
      avatarUrl: dto.avatar_url,
      bio: dto.bio,
      email: dto.email,
    });
    return { success: true, data: toMobileUser(data) };
  }

  @Get('me/items')
  @ApiOperation({ summary: '取得我發布的物品' })
  async getMyItems(@CurrentUser() user: User) {
    const data = await this.usersService.getMyItems(user.id);
    return { success: true, data: data.map(toMobileItem) };
  }

  @Get('me/stats')
  @ApiOperation({ summary: '我的統計資料（已登記 / 幫助次數 / 收藏）' })
  async getStats(@CurrentUser() user: User) {
    const data = await this.usersService.getStats(user.id);
    return { success: true, data };
  }

  @Get('me/badges')
  @ApiOperation({ summary: '我的成就徽章（含解鎖狀態與進度）' })
  async getBadges(@CurrentUser() user: User) {
    const data = await this.usersService.getBadges(user.id);
    return { success: true, data };
  }
}
