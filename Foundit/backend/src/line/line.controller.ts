import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { LineService } from './line.service';
import { BotSecretGuard } from './bot-secret.guard';
import { CreateLineLinkDto, FinderNoticeDto } from './dto/line.dto';

@ApiTags('LINE')
@Controller('line')
export class LineController {
  constructor(private readonly line: LineService) {}

  /** 只有 LINE webhook 能呼叫（x-bot-secret）。 */
  @Post('links')
  @UseGuards(BotSecretGuard)
  @ApiOperation({ summary: '替一位 LINE 使用者發一次性的「我撿到了」連結' })
  async issue(@Body() dto: CreateLineLinkDto) {
    const { token, expiresAt, uses } = await this.line.issueLink(dto.line_user, dto.ttl_minutes);
    return { success: true, token, expires_at: expiresAt.getTime(), uses };
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
