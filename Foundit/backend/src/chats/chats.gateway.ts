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
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ChatsService } from './chats.service';
import { SendMessageDto } from './dto/send-message.dto';
import { toMobileMessage } from './chat-mobile.serializer';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { AccessTokenPayload, assertActiveSession } from '../auth/session';
import { isUuid } from '../common/ids';

@WebSocketGateway({
  namespace: '/chat',
  cors: {
    origin: process.env.NODE_ENV === 'production'
      ? (process.env.CORS_ORIGINS ?? '').split(',').map((item) => item.trim()).filter(Boolean)
      : true,
  },
})
export class ChatsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ChatsGateway.name);
  private readonly socketsByUser = new Map<string, Set<string>>();

  constructor(
    private readonly chatsService: ChatsService,
    private readonly jwtService: JwtService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const authentication = this.extractUser(client);
      client.data.authentication = authentication;
      const user = await authentication;
      client.data.userId = user.id;
      client.data.user = user;
      client.data.authenticated = true;
      const bucket = this.socketsByUser.get(user.id) ?? new Set<string>();
      bucket.add(client.id);
      this.socketsByUser.set(user.id, bucket);
      this.logger.log(`用戶已連線 [${client.id}]`);
    } catch {
      client.data.authenticated = false;
      this.logger.warn(`未授權的 WebSocket 連線 [${client.id}]`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId as string | undefined;
    if (userId) {
      const bucket = this.socketsByUser.get(userId);
      bucket?.delete(client.id);
      if (bucket && bucket.size === 0) this.socketsByUser.delete(userId);
    }
    client.rooms.forEach((room) => {
      if (room !== client.id) client.leave(room);
    });
  }

  disconnectUser(userId: string) {
    for (const id of this.socketsByUser.get(userId) ?? []) {
      this.server?.to(id).disconnectSockets(true);
    }
    this.socketsByUser.delete(userId);
  }

  @SubscribeMessage('join')
  async handleJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId?: string },
  ) {
    const user = await this.requireUser(client);
    if (!isUuid(data?.chatId)) throw new WsException('聊天室不存在');
    await this.chatsService.assertParticipant(data.chatId, user.id);
    await client.join(`chat:${data.chatId}`);
    return { event: 'joined', chatId: data.chatId };
  }

  @SubscribeMessage('message')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId?: string; content?: string; type?: string; client_message_id?: string },
  ) {
    const user = await this.requireUser(client);
    this.consumeRate(client);
    if (!isUuid(data?.chatId)) throw new WsException('聊天室不存在');
    const dto = plainToInstance(SendMessageDto, {
      content: data?.content,
      type: data?.type,
      client_message_id: data?.client_message_id,
    });
    const errors = await validate(dto);
    if (errors.length > 0) throw new WsException('訊息格式不正確');
    const msg = await this.chatsService.sendMessage(data.chatId, dto, user);
    const payload = toMobileMessage(msg);
    this.server.to(`chat:${data.chatId}`).emit('message', payload);
    return payload;
  }

  @SubscribeMessage('read')
  async handleRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId?: string; upToMessageId?: string },
  ) {
    const user = await this.requireUser(client);
    if (!isUuid(data?.chatId) || !isUuid(data?.upToMessageId)) {
      throw new WsException('已讀範圍不正確');
    }
    await this.chatsService.markRead(data.chatId, user.id, data.upToMessageId);
    this.server.to(`chat:${data.chatId}`).emit('read', {
      chatId: data.chatId,
      userId: user.id,
      upToMessageId: data.upToMessageId,
    });
  }

  pushToChat(chatId: string, event: string, payload: unknown) {
    this.server?.to(`chat:${chatId}`).emit(event, payload);
  }

  private async requireUser(client: Socket): Promise<User> {
    try {
      await client.data.authentication;
    } catch {
      throw new WsException('未登入');
    }
    if (!client.data.authenticated) throw new WsException('未登入');
    const user = client.data.user as User | undefined;
    if (!user || user.status !== 'active') throw new WsException('未登入');
    return user;
  }

  private consumeRate(client: Socket) {
    const now = Date.now();
    const windowStart = (client.data.rateStart as number | undefined) ?? now;
    const count = (client.data.rateCount as number | undefined) ?? 0;
    if (now - windowStart > 60_000) {
      client.data.rateStart = now;
      client.data.rateCount = 1;
      return;
    }
    if (count >= 30) throw new WsException('訊息太頻繁');
    client.data.rateStart = windowStart;
    client.data.rateCount = count + 1;
  }

  private async extractUser(client: Socket): Promise<User> {
    const token =
      (client.handshake.auth?.token as string) ||
      (client.handshake.headers?.authorization as string);
    const cleaned = token?.replace('Bearer ', '') ?? '';
    const payload = this.jwtService.verify<AccessTokenPayload>(cleaned);
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    return assertActiveSession(user, payload.tv);
  }
}
