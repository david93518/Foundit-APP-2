import {
  Controller, Get, Post, Patch, Body, Param, Query, UseGuards,
  ParseIntPipe, DefaultValuePipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { toMobileChat, toMobileMessage } from './chat-mobile.serializer';
import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';

class MarkReadDto {
  @ApiProperty()
  @IsUUID()
  up_to_message_id: string;
}

@ApiTags('聊天')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chats')
export class ChatsController {
  constructor(
    private readonly chatsService: ChatsService,
    private readonly chatsGateway: ChatsGateway,
  ) {}

  @Post()
  @RateLimit({ name: 'chat-create', limit: 30, windowMs: 60 * 60_000, by: 'user' })
  @ApiOperation({ summary: '建立或取得聊天室' })
  async create(@Body() dto: CreateChatDto, @CurrentUser() user: User) {
    const chat = await this.chatsService.createOrGet(dto, user);
    // 新對話會帶一則系統訊息：讓物主的未讀角標立刻更新。
    await this.chatsGateway.pushInbox(chat.id);
    return { success: true, data: toMobileChat(chat, user.id) };
  }

  @Get()
  @ApiOperation({ summary: '取得我的聊天列表（含未讀數與最後訊息）' })
  async findAll(@CurrentUser() user: User) {
    const rows = await this.chatsService.findAllForUser(user.id);
    return { success: true, data: rows.map((c) => toMobileChat(c, user.id)) };
  }

  @Get('unread-count')
  @ApiOperation({ summary: '取得我的所有對話未讀總數（給 nav badge 用）' })
  async unreadCount(@CurrentUser() user: User) {
    const count = await this.chatsService.unreadTotalForUser(user.id);
    return { success: true, data: { count } };
  }

  @Get(':id/messages')
  @ApiOperation({ summary: '取得聊天室訊息' })
  async getMessages(
    @Param('id') id: string,
    @CurrentUser() user: User,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('before') before?: string,
    @Query('limit') limitRaw?: string,
  ) {
    const limit = Number(limitRaw ?? 50);
    const rows = await this.chatsService.getMessages(id, user.id, {
      limit: Number.isFinite(limit) ? limit : 50,
      before,
      page,
    });
    return { success: true, data: rows.map(toMobileMessage) };
  }

  @Get(':id')
  async detail(@Param('id') id: string, @CurrentUser() user: User) {
    return { success: true, data: toMobileChat(await this.chatsService.detailForUser(id, user.id), user.id) };
  }

  @Post(':id/messages')
  @RateLimit({ name: 'chat-send', limit: 60, windowMs: 60_000, by: 'user' })
  @ApiOperation({ summary: '發送訊息（REST，推薦用 WebSocket）' })
  async sendMessage(
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
    @CurrentUser() user: User,
  ) {
    const msg = await this.chatsService.sendMessage(id, dto, user);
    const payload = toMobileMessage(msg);
    await this.chatsGateway.pushToChat(id, 'message', payload);
    await this.chatsGateway.pushInbox(id);
    return { success: true, data: payload };
  }

  @Patch(':id/read')
  @RateLimit({ name: 'chat-read', limit: 120, windowMs: 60_000, by: 'user' })
  @ApiOperation({ summary: '將已載入、且不晚於指定訊息的對方訊息標為已讀' })
  async markRead(
    @Param('id') id: string,
    @Body() dto: MarkReadDto,
    @CurrentUser() user: User,
  ) {
    await this.chatsService.markRead(id, user.id, dto.up_to_message_id);
    await this.chatsGateway.pushToChat(id, 'read', {
      chatId: id,
      userId: user.id,
      upToMessageId: dto.up_to_message_id,
    });
    await this.chatsGateway.pushInbox(id, [user.id]);
    return { success: true };
  }
}
