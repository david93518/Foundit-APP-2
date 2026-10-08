import { Controller, Get, Post, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { GenerateQrDto } from './dto/generate-qr.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { toPublicProfile } from '../users/public-profile';

function toMobileQrItem(q: QrItem): Record<string, unknown> {
  return {
    id: q.id,
    user_id: q.userId,
    name: q.name,
    description: q.description ?? '',
    qr_code: q.qrCode,
    qr_image_url: q.qrImageUrl ?? '',
    created_at: q.createdAt ? new Date(q.createdAt).getTime() : Date.now(),
  };
}

@ApiTags('QR Code')
@Controller('qr')
export class QrController {
  constructor(private readonly qrService: QrService) {}

  @Post('generate')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '產生 QR Code 防丟貼紙' })
  async generate(@Body() dto: GenerateQrDto, @CurrentUser() user: User) {
    const data = await this.qrService.generate(dto, user);
    return { success: true, data: toMobileQrItem(data) };
  }

  @Get('items')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '取得我的 QR 物品清單' })
  async findAll(@CurrentUser() user: User) {
    const data = await this.qrService.findAllByUser(user.id);
    return { success: true, data: data.map(toMobileQrItem) };
  }

  @Delete('items/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '刪除 QR 物品' })
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.qrService.remove(id, user);
    return { success: true, message: '已刪除' };
  }

  @Get('scan/:code')
  @ApiOperation({ summary: '掃描 QR Code（公開端點）' })
  async scan(@Param('code') code: string) {
    const { qrItem, owner } = await this.qrService.scanByCode(code);
    return {
      success: true,
      qr_item: toMobileQrItem(qrItem),
      owner: toPublicProfile(owner),
    };
  }
}
