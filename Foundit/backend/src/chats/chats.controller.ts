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
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';

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
  @ApiOperation({ summary: '建立或取得聊天室' })
  async create(@Body() dto: CreateChatDto, @CurrentUser() user: User) {
    const chat = await this.chatsService.createOrGet(dto, user);
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
    @Query('page_size', new DefaultValuePipe(50), ParseIntPipe) pageSize: number,
  ) {
    const rows = await this.chatsService.getMessages(id, user.id, page, pageSize);
    return { success: true, data: rows.map(toMobileMessage) };
  }

  @Post(':id/messages')
  @ApiOperation({ summary: '發送訊息（REST，推薦用 WebSocket）' })
  async sendMessage(
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
    @CurrentUser() user: User,
  ) {
    const msg = await this.chatsService.sendMessage(id, dto, user);
    const payload = toMobileMessage(msg);
    this.chatsGateway.pushToChat(id, 'message', payload);
    return { success: true, data: payload };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: '將聊天室所有對方訊息標記為已讀' })
  async markRead(@Param('id') id: string, @CurrentUser() user: User) {
    await this.chatsService.markRead(id, user.id);
    this.chatsGateway.pushToChat(id, 'read', { chatId: id, userId: user.id });
    return { success: true };
  }
}
