import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { CreateQrBatchDto, DisableQrDto } from './dto/qr-batch.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { QrBatch } from '../common/entities/qr-batch.entity';
import { QrItem } from '../common/entities/qr-item.entity';

function toAdminBatch(b: QrBatch, extra: { bound?: number; disabled?: number } = {}): Record<string, unknown> {
  return {
    id: b.id,
    label: b.label,
    place: b.place ?? '',
    count: b.count,
    bound: extra.bound,
    disabled: extra.disabled,
    created_at: b.createdAt ? new Date(b.createdAt).getTime() : null,
  };
}

function toAdminSticker(q: QrItem, url: string): Record<string, unknown> {
  const state = q.disabledAt ? 'disabled' : q.revokedAt ? 'revoked' : q.boundAt ? 'bound' : 'unbound';
  return { id: q.id, code: q.code, url, state, bound_at: q.boundAt ? new Date(q.boundAt).getTime() : null };
}

@ApiTags('管理')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/qr')
export class QrAdminController {
  constructor(private readonly qrService: QrService) {}

  @Post('batches')
  @ApiOperation({ summary: '印製一批貼紙：產生編號，使用者拿到後再綁定' })
  async create(@Body() dto: CreateQrBatchDto, @CurrentUser() admin: User) {
    const { batch, codes } = await this.qrService.createBatch(dto, admin);
    return {
      success: true,
      batch: toAdminBatch(batch, { bound: 0, disabled: 0 }),
      codes: codes.map((code) => ({ code, url: this.qrService.publicUrl({ code, qrCode: '' }) })),
    };
  }

  @Get('batches')
  @ApiOperation({ summary: '貼紙批次列表，含已綁定與已停用張數' })
  async list() {
    const batches = await this.qrService.listBatches();
    return { success: true, data: batches.map((b) => toAdminBatch(b, { bound: b.bound, disabled: b.disabled })) };
  }

  @Get('batches/:id/codes')
  @ApiOperation({ summary: '某批次的所有編號與狀態' })
  async codes(@Param('id', new ParseUUIDPipe()) id: string) {
    const { batch, items } = await this.qrService.batchCodes(id);
    return {
      success: true,
      batch: toAdminBatch(batch),
      data: items.map((q) => toAdminSticker(q, this.qrService.publicUrl(q))),
    };
  }

  @Post('disable')
  @ApiOperation({ summary: '停用單張或整批貼紙（遺失、印錯）' })
  async disable(@Body() dto: DisableQrDto) {
    const affected = await this.qrService.disable({ code: dto.code, batchId: dto.batch_id });
    return { success: true, affected };
  }
}
