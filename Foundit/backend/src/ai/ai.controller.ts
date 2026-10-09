import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { AiService } from './ai.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { toMobileItem } from '../items/item-mobile.serializer';
import { RateLimit } from '../common/abuse-limit.interceptor';

class AiMatchDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  item_id?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  image_url?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  keyword?: string;
}

@ApiTags('AI 配對')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('match')
  @RateLimit({ name: 'ai-match', limit: 30, windowMs: 60_000, by: 'user' })
  @ApiOperation({ summary: 'AI 智慧配對（關鍵字 + 規則比對）' })
  async match(@Body() dto: AiMatchDto, @CurrentUser() user: User) {
    const results = await this.aiService.match({
      itemId: dto.item_id,
      imageUrl: dto.image_url,
      keyword: dto.keyword,
    });
    const data = results.map((r) => ({
      item: toMobileItem(r.item, user.id),
      score: r.score,
      similarity_percent: r.similarityPercent,
    }));
    return { success: true, data };
  }
}
