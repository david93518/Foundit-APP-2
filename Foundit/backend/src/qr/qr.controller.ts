import { Controller, Get, Post, Patch, Delete, Body, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { GenerateQrDto } from './dto/generate-qr.dto';
import { BindQrDto, UpdateQrDto } from './dto/bind-qr.dto';
import { QrScanNotifier } from './qr-scan-notifier.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';
import { OptionalJwtAuthGuard } from '../common/guards/optional-jwt-auth.guard';

/** 物主自己的防丟牌清單。code 是印在貼紙上的編號（新貼紙 6 碼，舊的自行產生是 UUID）。 */
function toMobileQrItem(q: QrItem, publicUrl: string): Record<string, unknown> {
  return {
    id: q.id,
    code: q.code ?? '',
    name: q.name,
    description: q.description ?? '',
    qr_code: publicUrl,
    qr_image_url: q.qrImageUrl ?? '',
    bound_at: q.boundAt ? new Date(q.boundAt).getTime() : null,
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

  /** 舊版 App 用。QR_SELF_GENERATE=false 時回 410，改由官方印製的貼紙綁定（POST /qr/bind）。 */
  @Post('generate')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'qr-generate', limit: 30, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '（舊版）自行產生防丟貼紙；新流程請用 POST /qr/bind', deprecated: true })
  async generate(@Body() dto: GenerateQrDto, @CurrentUser() user: User) {
    const data = await this.qrService.generate(dto, user);
    return { success: true, data: toMobileQrItem(data, this.qrService.publicUrl(data)) };
  }

  @Post('bind')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'qr-bind', limit: 30, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '輸入貼紙編號，綁定到自己的帳號' })
  async bind(@Body() dto: BindQrDto, @CurrentUser() user: User) {
    const data = await this.qrService.bind(dto, user);
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
  @ApiOperation({ summary: '修改貼紙名稱或備註（貼紙代碼不變）' })
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
  @ApiOperation({ summary: '撤銷貼紙（永久失效）' })
  async remove(@Param('id', new ParseUUIDPipe()) id: string, @CurrentUser() user: User) {
    await this.qrService.remove(id, user);
    return { success: true, message: '已撤銷' };
  }

  /** App 掃到貼紙後先問狀態：沒人綁定就顯示「綁定」，已綁定就顯示「聯絡物主」。只回狀態，不回物主任何資料。 */
  @Get('status/:code')
  @RateLimit({ name: 'qr-status', limit: 60, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '貼紙目前的狀態（公開端點）：unbound / active / disabled / revoked / invalid' })
  async status(@Param('code') code: string) {
    const { state } = await this.qrService.inspect(code);
    return { success: true, state };
  }

  @Get('scan/:code')
  @UseGuards(OptionalJwtAuthGuard)
  @RateLimit({ name: 'qr-scan', limit: 60, windowMs: 10 * 60_000, by: 'ip' })
  @ApiOperation({ summary: '掃描 QR Code（公開端點，只有已綁定的貼紙掃得到）' })
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
