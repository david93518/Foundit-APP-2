import { BadRequestException, Body, Controller, Get, Headers, HttpCode, Param, Post, Req } from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import { ApiExcludeEndpoint, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { LineService } from './line.service';
import { LineBotService } from './line-bot.service';
import { FinderNoticeDto } from './dto/line.dto';

@ApiTags('LINE')
@Controller('line')
export class LineController {
  constructor(
    private readonly line: LineService,
    private readonly bot: LineBotService,
  ) {}

  /**
   * LINE 官方帳號的 webhook。不用 JWT：身分由 x-line-signature 驗證（頻道密鑰對原始內容的 HMAC）。
   * 一律回 200，LINE 才不會因為單一事件失敗而重送整批。
   */
  @Post('webhook')
  @HttpCode(200)
  @ApiExcludeEndpoint()
  async webhook(@Req() req: RawBodyRequest<Request>, @Headers('x-line-signature') signature?: string) {
    if (!req.rawBody) throw new BadRequestException('缺少內容');
    await this.bot.handleWebhook(req.rawBody, signature);
    return { success: true };
  }

  @Get('links/:token')
  @ApiOperation({ summary: '查連結還能不能用（公開，不需登入）' })
  async status(@Param('token') token: string) {
    const s = await this.line.status(token);
    return {
      success: true,
      status: s.status,
      uses_left: 'usesLeft' in s ? s.usesLeft : 0,
      expires_at: 'expiresAt' in s ? s.expiresAt.getTime() : null,
    };
  }

  @Post('links/:token/notify')
  @ApiOperation({ summary: '撿到的人留言，平台轉達給貼紙物主（公開，不需登入）' })
  async notify(@Param('token') token: string, @Body() dto: FinderNoticeDto) {
    const r = await this.line.notifyOwner(token, dto);
    return { success: true, name: r.name, uses_left: r.usesLeft };
  }
}
