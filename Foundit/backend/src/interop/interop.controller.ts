import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ModerationService } from '../moderation/moderation.service';
import { DataSource } from 'typeorm';
import { IsString, Length } from 'class-validator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { ItemsService } from '../items/items.service';
import { PointsService } from '../points/points.service';
import { PointEventType } from '../common/entities/point-event.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';

class ScanDto {
  @IsString() @Length(1, 200) code: string;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class InteropController {
  constructor(
    private readonly db: DataSource,
    private readonly items: ItemsService,
    private readonly points: PointsService,
    private readonly moderation: ModerationService,
  ) {}
  @Post('items/:id/block')
  @RateLimit({ name: 'block', limit: 60, windowMs: 3600000, by: 'user' })
  async blockItem(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    const item = await this.items.findOne(id, user.id);
    await this.moderation.block(user, item.userId);
    return { success: true };
  }
  @Get('users/me/bookmarks')
  async bookmarks(@CurrentUser() user: User) {
    const rows = await this.db.query(
      `SELECT s.item_id FROM saved_items s JOIN items i ON i.id=s.item_id
      WHERE s.user_id=$1 AND i.hidden_at IS NULL AND (i.status='ACTIVE' OR i.user_id=$1) ORDER BY s.created_at DESC`,
      [user.id],
    );
    return { success: true, data: rows.map((r) => r.item_id) };
  }
  @Put('users/me/bookmarks/:id')
  @RateLimit({ name: 'bookmark', limit: 120, windowMs: 60000, by: 'user' })
  async save(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    await this.items.findOne(id, user.id);
    await this.db.query(
      'INSERT INTO saved_items(user_id,item_id) VALUES($1,$2) ON CONFLICT DO NOTHING',
      [user.id, id],
    );
    return { success: true };
  }
  @Delete('users/me/bookmarks/:id')
  async unsave(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    await this.db.query(
      'DELETE FROM saved_items WHERE user_id=$1 AND item_id=$2',
      [user.id, id],
    );
    return { success: true };
  }
  @Delete('chats/:id')
  async hide(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: User,
  ) {
    const rows = await this.db.query(
      `INSERT INTO hidden_chats(user_id,chat_id)
      SELECT user_id,chat_id FROM chat_participants WHERE user_id=$1 AND chat_id=$2
      ON CONFLICT(user_id,chat_id) DO UPDATE SET hidden_at=now() RETURNING chat_id`,
      [user.id, id],
    );
    if (!rows.length) throw new NotFoundException('對話不存在');
    return { success: true };
  }
  @Post('users/me/points/daily')
  @RateLimit({ name: 'daily', limit: 30, windowMs: 60000, by: 'user' })
  async daily(@CurrentUser() user: User) {
    const day = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Taipei',
    }).format(new Date());
    return {
      success: true,
      awarded: await this.points.award(
        user.id,
        PointEventType.DAILY_LOGIN,
        day,
        '每日登入',
      ),
    };
  }
  @Post('users/me/points/scan')
  @RateLimit({ name: 'scan-award', limit: 30, windowMs: 60000, by: 'user' })
  async scan(@Body() dto: ScanDto, @CurrentUser() user: User) {
    const code = dto.code.replace(/^https:\/\/api\.foundit\.tw\/qr\//, '');
    const rows = await this.db.query(
      `SELECT id FROM qr_items WHERE (code=$1 OR qr_code=$1)
      AND revoked_at IS NULL AND user_id<>$2`,
      [code, user.id],
    );
    if (!rows.length) return { success: true, awarded: false };
    return {
      success: true,
      awarded: await this.points.award(
        user.id,
        PointEventType.QR_SCAN,
        rows[0].id,
        '掃描防丟牌',
      ),
    };
  }
}
