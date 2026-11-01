import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, GoneException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { BindQrDto, UpdateQrDto } from './dto/bind-qr.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { toPublicProfile } from '../users/public-profile';

function toMobileQrItem(q: QrItem, publicUrl: string): Record<string, unknown> {
  return {
    id: q.id,
    user_id: q.userId ?? '',
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
  constructor(private readonly qrService: QrService) {}

  /** 自行產生已停用：貼紙由官方印製，使用者拿到後輸入編號綁定（POST /qr/bind）。 */
  @Post('generate')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '已停用：改用 POST /qr/bind 綁定官方貼紙', deprecated: true })
  generate(): never {
    throw new GoneException('貼紙改由官方發放，請輸入貼紙上的編號綁定');
  }

  @Post('bind')
  @UseGuards(JwtAuthGuard)
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
  @ApiBearerAuth()
  @ApiOperation({ summary: '修改貼紙名稱或備註' })
  async update(@Param('id') id: string, @Body() dto: UpdateQrDto, @CurrentUser() user: User) {
    const data = await this.qrService.update(id, dto, user);
    return { success: true, data: toMobileQrItem(data, this.qrService.publicUrl(data)) };
  }

  @Delete('items/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '撤銷貼紙（永久失效）' })
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.qrService.remove(id, user);
    return { success: true, message: '已撤銷' };
  }

  @Get('scan/:code')
  @ApiOperation({ summary: '掃描 QR Code（公開端點，只有已綁定的貼紙掃得到）' })
  async scan(@Param('code') code: string) {
    const { qrItem, owner } = await this.qrService.scanByCode(code);
    return {
      success: true,
      qr_item: toMobileQrItem(qrItem, this.qrService.publicUrl(qrItem)),
      owner: toPublicProfile(owner),
    };
  }
}
