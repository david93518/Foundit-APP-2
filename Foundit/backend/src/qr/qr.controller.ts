import { Controller, Get, Post, Patch, Delete, Body, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { GenerateQrDto, UpdateQrDto } from './dto/generate-qr.dto';
import { QrScanNotifier } from './qr-scan-notifier.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';
import { OptionalJwtAuthGuard } from '../common/guards/optional-jwt-auth.guard';

/** 物主自己的防丟牌清單。 */
function toMobileQrItem(q: QrItem, publicUrl: string): Record<string, unknown> {
  return {
    id: q.id,
    name: q.name,
    description: q.description ?? '',
    qr_code: publicUrl,
    qr_image_url: q.qrImageUrl ?? '',
    created_at: q.createdAt ? new Date(q.createdAt).getTime() : Date.now(),
  };
}

@ApiTags('QR Code')
@Controller('qr')
export class QrController {
  constructor(
    private readonly qrService: QrService,
    private readonly scanNotifier: QrScanNotifier,
  ) {}

  @Post('generate')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'qr-generate', limit: 30, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '產生 QR Code 防丟貼紙' })
  async generate(@Body() dto: GenerateQrDto, @CurrentUser() user: User) {
    const data = await this.qrService.generate(dto, user);
    return { success: true, data: toMobileQrItem(data, this.qrService.publicUrl(data)) };
  }

  @Get('items')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '取得我的 QR 物品清單' })
  async findAll(@CurrentUser() user: User) {
    const data = await this.qrService.findAllByUser(user.id);
    return { success: true, data: data.map((q) => toMobileQrItem(q, this.qrService.publicUrl(q))) };
  }

  @Patch('items/:id')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'qr-update', limit: 60, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '修改 QR 物品名稱與備註（貼紙代碼不變）' })
  async update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateQrDto,
    @CurrentUser() user: User,
  ) {
    const data = await this.qrService.update(id, dto, user);
    return { success: true, data: toMobileQrItem(data, this.qrService.publicUrl(data)) };
  }

  @Delete('items/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '刪除 QR 物品' })
  async remove(@Param('id', new ParseUUIDPipe()) id: string, @CurrentUser() user: User) {
    await this.qrService.remove(id, user);
    return { success: true, message: '已刪除' };
  }

  @Get('scan/:code')
  @UseGuards(OptionalJwtAuthGuard)
  @RateLimit({ name: 'qr-scan', limit: 60, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '掃描 QR Code（公開端點）' })
  async scan(@Param('code') code: string, @CurrentUser() viewer?: User) {
    const { qrItem, owner } = await this.qrService.scanByCode(code);
    const isOwnTag = viewer?.id === owner.id;
    if (viewer && !isOwnTag) this.scanNotifier.scanned(qrItem, owner, 'app');
    // A boolean replaces the stable account identifier, so separate tags cannot be correlated.
    return {
      success: true,
      qr_item: { name: qrItem.name },
      owner: { name: owner.name ?? '' },
      is_own_tag: isOwnTag,
    };
  }
}
