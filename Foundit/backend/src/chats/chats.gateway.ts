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
import { FixedWindowLimiter } from '../common/fixed-window-limiter';

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
  /** 同一帳號同時連線的上限；超過時踢掉最舊的連線，避免單一帳號佔滿伺服器。 */
  private readonly maxSocketsPerUser = 8;
  private readonly events = new FixedWindowLimiter(120, 60_000);

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
      if (!client.connected) return;
      client.data.userId = user.id;
      client.data.user = user;
      client.data.authenticated = true;
      const payload = this.jwtService.decode<{ exp: number }>(client.data.token as string);
      client.data.expiryTimer = setTimeout(() => client.disconnect(true),
        Math.min(payload.exp * 1000 - Date.now(), 2_147_483_647));
      client.data.expiryTimer.unref();
      // Also remove idle sockets revoked through another API replica or an operator's DB update.
      client.data.sessionTimer = setInterval(() => {
        void this.requireUser(client).catch(() => client.disconnect(true));
      }, 5_000);
      client.data.sessionTimer.unref();
      // 每個帳號一個房間：未讀角標的即時更新與對方是否在線上都靠它，跨 API 副本也成立。
      await client.join(this.userRoom(user.id));
      const bucket = this.socketsByUser.get(user.id) ?? new Set<string>();
      bucket.add(client.id);
      this.socketsByUser.set(user.id, bucket);
      while (bucket.size > this.maxSocketsPerUser) {
        const oldest = bucket.values().next().value as string;
        bucket.delete(oldest);
        this.server?.to(oldest).disconnectSockets(true);
      }
      this.logger.log(`用戶已連線 [${client.id}]`);
    } catch {
      client.data.authenticated = false;
      this.logger.warn(`未授權的 WebSocket 連線 [${client.id}]`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    clearTimeout(client.data.expiryTimer as NodeJS.Timeout | undefined);
    clearInterval(client.data.sessionTimer as NodeJS.Timeout | undefined);
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
    this.consumeRate(user.id);
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
    this.consumeRate(user.id);
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
    await this.pushToChat(data.chatId, 'message', payload);
    await this.pushInbox(data.chatId);
    return payload;
  }

  /** 對方目前是否有開著 App（有任何一條已驗證的連線）。只回答同一個聊天室的參與者。 */
  @SubscribeMessage('presence')
  async handlePresence(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId?: string },
  ) {
    const user = await this.requireUser(client);
    this.consumeRate(user.id);
    if (!isUuid(data?.chatId)) throw new WsException('聊天室不存在');
    await this.chatsService.assertParticipant(data.chatId, user.id);
    const peers = (await this.chatsService.participantIds(data.chatId)).filter((id) => id !== user.id);
    let online = false;
    for (const peer of peers) {
      const sockets = await this.server.in(this.userRoom(peer)).fetchSockets();
      if (sockets.some((socket) => socket.data.authenticated === true)) online = true;
    }
    return { chatId: data.chatId, online };
  }

  @SubscribeMessage('read')
  async handleRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { chatId?: string; upToMessageId?: string },
  ) {
    const user = await this.requireUser(client);
    this.consumeRate(user.id);
    if (!isUuid(data?.chatId) || !isUuid(data?.upToMessageId)) {
      throw new WsException('已讀範圍不正確');
    }
    await this.chatsService.markRead(data.chatId, user.id, data.upToMessageId);
    await this.pushToChat(data.chatId, 'read', {
      chatId: data.chatId,
      userId: user.id,
      upToMessageId: data.upToMessageId,
    });
    await this.pushInbox(data.chatId, [user.id]);
  }

  /**
   * 告訴參與者「這個對話有變動」，App 會重新抓聊天列表與未讀數。只送 chatId，不帶內容；
   * 沒開這個聊天室的人也收得到（例如停在首頁時，底部「訊息」角標要跟著更新）。
   */
  async pushInbox(chatId: string, userIds?: string[]): Promise<void> {
    if (!this.server) return;
    const recipients = userIds ?? await this.chatsService.participantIds(chatId);
    for (const id of recipients) {
      this.server.to(this.userRoom(id)).emit('inbox', { chatId });
    }
  }

  private userRoom(userId: string): string {
    return `user:${userId}`;
  }

  async pushToChat(chatId: string, event: string, payload: unknown): Promise<void> {
    if (!this.server) return;
    const sockets = await this.server.in(`chat:${chatId}`).fetchSockets();
    await Promise.all(sockets.map(async (socket) => {
      try {
        // Validate the recipient before every delivery, including idle listeners on another replica.
        const user = await this.verifyToken(socket.data.token as string);
        await this.chatsService.assertParticipant(chatId, user.id);
        socket.emit(event, payload);
      } catch { socket.disconnect(true); }
    }));
  }

  private async requireUser(client: Socket): Promise<User> {
    try {
      await client.data.authentication;
    } catch {
      throw new WsException('未登入');
    }
    if (!client.data.authenticated) throw new WsException('未登入');
    try {
      return await this.verifyToken(client.data.token as string);
    } catch {
      client.disconnect(true);
      throw new WsException('登入已失效');
    }
  }

  /** Account-wide event quota survives reconnects; message writes additionally share a DB quota. */
  private consumeRate(userId: string) {
    if (!this.events.allow(userId)) throw new WsException('操作太頻繁');
  }

  private async extractUser(client: Socket): Promise<User> {
    const token =
      (client.handshake.auth?.token as string) ||
      (client.handshake.headers?.authorization as string);
    const cleaned = typeof token === 'string' ? token.replace(/^Bearer /i, '') : '';
    client.data.token = cleaned;
    return this.verifyToken(cleaned);
  }

  private async verifyToken(token: string): Promise<User> {
    if (!token || token.length > 8192) throw new WsException('未登入');
    const payload = this.jwtService.verify<AccessTokenPayload & { exp: number }>(token, { algorithms: ['HS256'] });
    if (!isUuid(payload.sub) || !Number.isFinite(payload.exp) || payload.exp * 1000 <= Date.now()) {
      throw new WsException('登入已失效');
    }
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    return assertActiveSession(user, payload.tv);
  }
}
