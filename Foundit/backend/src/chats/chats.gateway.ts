import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ChatsService } from './chats.service';
import { SendMessageDto } from './dto/send-message.dto';
import { toMobileMessage } from './chat-mobile.serializer';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';

/**
 * WebSocket 聊天閘道器
 * 前端連線範例：
 *   const socket = io('ws://localhost:3000/chat', { auth: { token: 'Bearer ...' } });
 *   socket.emit('join', { chatId });
 *   socket.emit('message', { chatId, content: '...' });
 *   socket.on('message', (msg) => { ... });
 */
@WebSocketGateway({ namespace: '/chat', cors: { origin: '*' } })
export class ChatsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ChatsGateway.name);

  constructor(
    private readonly chatsService: ChatsService,
    private readonly jwtService: JwtService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const user = await this.extractUser(client);
      client.data.userId = user.id;
      client.data.user = user;
      this.logger.log(`用戶 ${user.name} 已連線 [${client.id}]`);
    } catch {
      this.logger.warn(`未授權的 WebSocket 連線 [${client.id}]`);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Socket 斷線 [${client.id}]`);
  }

  @SubscribeMessage('join')
  async handleJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId: string },
  ) {
    await client.join(`chat:${data.chatId}`);
    return { event: 'joined', chatId: data.chatId };
  }

  @SubscribeMessage('message')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId: string; content: string; type?: string },
  ) {
    const user = client.data.user as User;
    if (!user) throw new WsException('未登入');

    const msg = await this.chatsService.sendMessage(
      data.chatId,
      { content: data.content, type: data.type as any },
      user,
    );

    const payload = toMobileMessage(msg);
    this.server.to(`chat:${data.chatId}`).emit('message', payload);
    return payload;
  }

  @SubscribeMessage('read')
  async handleRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId: string },
  ) {
    await this.chatsService.markRead(data.chatId, client.data.userId);
    this.server.to(`chat:${data.chatId}`).emit('read', {
      chatId: data.chatId,
      userId: client.data.userId,
    });
  }

  /** 由其他 Service 呼叫，主動推送系統通知 */
  pushToChat(chatId: string, event: string, payload: any) {
    this.server.to(`chat:${chatId}`).emit(event, payload);
  }

  private async extractUser(client: Socket): Promise<User> {
    const token =
      (client.handshake.auth?.token as string) ||
      (client.handshake.headers?.authorization as string);
    const cleaned = token?.replace('Bearer ', '') ?? '';
    const payload = this.jwtService.verify<{ sub: string }>(cleaned);
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    if (!user) throw new WsException('用戶不存在');
    return user;
  }
}
