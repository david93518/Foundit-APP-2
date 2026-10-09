import {
  BadRequestException, ForbiddenException, HttpException, Injectable, Logger, NotFoundException, Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { Chat } from '../common/entities/chat.entity';
import { Message, MessageType } from '../common/entities/message.entity';
import { Item, ItemStatus } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { Block } from '../common/entities/block.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { isUuid } from '../common/ids';
import { QrService } from '../qr/qr.service';
import { ChatPushService } from './chat-push.service';
import { publicBaseUrl, uploadSecret } from '../common/media-url';
import { isOwnPrivateImage } from '../upload/private-media';

type ChatSubject = {
  key: { itemId: string } | { qrItemId: string };
  isQr: boolean;
  owner: User;
  title: string;
};

@Injectable()
export class ChatsService {
  private readonly logger = new Logger(ChatsService.name);

  constructor(
    @InjectRepository(Chat) private readonly chatRepo: Repository<Chat>,
    @InjectRepository(Message) private readonly msgRepo: Repository<Message>,
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
    @InjectRepository(Block) private readonly blockRepo: Repository<Block>,
    private readonly qrService: QrService,
    private readonly chatPush: ChatPushService,
    @Optional() private readonly config?: ConfigService,
  ) {}

  async createOrGet(dto: CreateChatDto, requester: User): Promise<Chat> {
    if (dto.item_id && dto.qr_code) {
      throw new BadRequestException('請只選擇一個聯絡對象');
    }
    const subject = dto.qr_code
      ? await this.qrSubject(dto.qr_code)
      : await this.itemSubject(dto.item_id ?? '');
    if (subject.owner.id === requester.id) {
      throw new BadRequestException(
        subject.isQr ? '這是你自己的防丟牌' : '不能和自己的物品開啟聊天',
      );
    }
    if (subject.owner.status !== 'active') {
      throw new BadRequestException('無法聯絡這個物主');
    }
    await this.assertNotBlocked(requester.id, subject.owner.id);

    const where = { ...subject.key, requesterId: requester.id };
    const { id: chatId, created } = await this.chatRepo.manager.transaction(async (manager) => {
      const existing = await manager.findOne(Chat, { where });
      if (existing) return { id: existing.id, created: false };

      const chat = manager.create(Chat, { itemId: null, qrItemId: null, ...where });
      chat.participants = [requester, subject.owner];
      try {
        const saved = await manager.save(chat);
        await manager.save(manager.create(Message, {
          chatId: saved.id,
          senderId: requester.id,
          content: subject.isQr
            ? `${requester.name} 掃描了防丟牌「${subject.title}」並發起聯絡`
            : `${requester.name} 就「${subject.title}」發起聯絡`,
          type: MessageType.SYSTEM,
        }));
        return { id: saved.id, created: true };
      } catch (error) {
        if (!this.isUniqueViolation(error)) throw error;
        const again = await manager.findOne(Chat, { where });
        if (!again) throw error;
        return { id: again.id, created: false };
      }
    });
    const chat = await this.loadChat(chatId);
    if (created && subject.isQr) {
      this.background(() => this.chatPush.tagScanned(chat, requester, subject.title));
    }
    return chat;
  }

  private async itemSubject(itemId: string): Promise<ChatSubject> {
    const item = await this.itemRepo.findOne({
      where: { id: itemId },
      relations: ['user'],
    });
    if (!item || item.status !== ItemStatus.ACTIVE || item.hiddenAt || !item.user) {
      throw new NotFoundException('物品不存在');
    }
    return { key: { itemId: item.id }, isQr: false, owner: item.user, title: item.title };
  }

  /** scanByCode 已排除撤銷的貼紙與已刪除的帳號。 */
  private async qrSubject(code: string): Promise<ChatSubject> {
    const { qrItem, owner } = await this.qrService.scanByCode(code);
    return { key: { qrItemId: qrItem.id }, isQr: true, owner, title: qrItem.name };
  }

  async findAllForUser(
    userId: string,
  ): Promise<Array<Chat & { unreadCount: number; lastMessage: Message | null }>> {
    const chats = await this.chatRepo
      .createQueryBuilder('chat')
      .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
      .leftJoinAndSelect('chat.participants', 'participant')
      .leftJoinAndSelect('chat.item', 'item')
      .leftJoinAndSelect('chat.qrItem', 'qrItem')
      .orderBy('chat.updated_at', 'DESC')
      .getMany();

    if (chats.length === 0) return [];
    const chatIds = chats.map((chat) => chat.id);
    const [lastMsgs, unreadRows] = await Promise.all([
      this.msgRepo
        .createQueryBuilder('m')
        .where('m.chat_id IN (:...ids)', { ids: chatIds })
        .andWhere(
          'm.created_at = (SELECT MAX(m2.created_at) FROM messages m2 WHERE m2.chat_id = m.chat_id)',
        )
        .getMany(),
      this.msgRepo
        .createQueryBuilder('m')
        .select('m.chat_id', 'chat_id')
        .addSelect('COUNT(*)', 'count')
        .where('m.chat_id IN (:...ids)', { ids: chatIds })
        .andWhere('m.sender_id != :uid', { uid: userId })
        .andWhere('m.read_at IS NULL')
        .groupBy('m.chat_id')
        .getRawMany<{ chat_id: string; count: string }>(),
    ]);

    const lastByChat = new Map<string, Message>();
    lastMsgs.forEach((message) => lastByChat.set(message.chatId, message));
    const unreadByChat = new Map<string, number>();
    unreadRows.forEach((row) => unreadByChat.set(row.chat_id, Number(row.count)));

    return chats.map((chat) => Object.assign(chat, {
      unreadCount: unreadByChat.get(chat.id) ?? 0,
      lastMessage: lastByChat.get(chat.id) ?? null,
    }));
  }

  async unreadTotalForUser(userId: string): Promise<number> {
    return this.msgRepo
      .createQueryBuilder('m')
      .innerJoin('chat_participants', 'cp', 'cp.chat_id = m.chat_id')
      .where('cp.user_id = :uid', { uid: userId })
      .andWhere('m.sender_id != :uid', { uid: userId })
      .andWhere('m.read_at IS NULL')
      .getCount();
  }

  /** 最新一頁在前。before 往上補更舊的訊息，回傳仍依時間升冪。 */
  async getMessages(
    chatId: string,
    userId: string,
    options: { limit?: number; before?: string; page?: number } = {},
  ): Promise<Message[]> {
    await this.assertParticipant(chatId, userId);
    const limit = Math.min(Math.max(options.limit ?? 50, 1), 50);
    // 深分頁會讓資料庫掃過大量資料；更舊的訊息請用 before 游標往前翻。
    const page = Math.min(Math.max(options.page ?? 1, 1), 200);
    const qb = this.msgRepo
      .createQueryBuilder('m')
      .leftJoinAndSelect('m.sender', 'sender')
      .where('m.chat_id = :chatId', { chatId })
      .orderBy('m.createdAt', 'DESC')
      .addOrderBy('m.id', 'DESC')
      .take(limit);

    if (options.before) {
      if (!isUuid(options.before)) throw new BadRequestException('歷史訊息範圍不正確');
      const pivot = await this.msgRepo.findOne({ where: { id: options.before, chatId } });
      if (!pivot) throw new BadRequestException('歷史訊息範圍不正確');
      // 時間在資料庫內比較：PostgreSQL 存到微秒，JS Date 只有毫秒，帶回來比會漏掉同一毫秒內的訊息。
      qb.andWhere(
        `(m.created_at, m.id) < (SELECT p.created_at, p.id FROM messages p WHERE p.id = :beforeId)`,
        { beforeId: pivot.id },
      );
    } else if (page > 1) {
      qb.skip((page - 1) * limit);
    }

    const rows = await qb.getMany();
    return rows.reverse();
  }

  async sendMessage(chatId: string, dto: SendMessageDto, sender: User): Promise<Message> {
    if (sender.status !== 'active') throw new ForbiddenException('帳號無法發送訊息');
    await this.assertParticipant(chatId, sender.id);
    const chat = await this.loadChat(chatId);
    const other = chat.participants?.find((person) => person.id !== sender.id);
    if (other) await this.assertNotBlocked(sender.id, other.id);

    if (dto.type === MessageType.SYSTEM) {
      throw new BadRequestException('不能建立系統訊息');
    }
    // 圖片訊息只能是傳送者本人上傳到本站的圖，對方的 App 不會被導去載入第三方網址。
    if (dto.type === MessageType.IMAGE &&
        !isOwnPrivateImage(dto.content.trim(), sender.id, publicBaseUrl(this.config), uploadSecret(this.config))) {
      throw new BadRequestException('聊天圖片必須使用私人圖片上傳入口');
    }
    if (dto.client_message_id) {
      const existing = await this.msgRepo.findOne({
        where: { chatId, senderId: sender.id, clientMessageId: dto.client_message_id },
        relations: ['sender'],
      });
      if (existing) return existing;
    }

    // PostgreSQL serializes updates for this account: REST, all sockets and all API replicas share the quota.
    const quota: Array<{ count: number }> = await this.chatRepo.manager.query(`
      INSERT INTO chat_rate_limits(user_id, window_start, count) VALUES ($1, clock_timestamp(), 1)
      ON CONFLICT (user_id) DO UPDATE SET
        count = CASE WHEN chat_rate_limits.window_start <= clock_timestamp() - interval '1 minute'
          THEN 1 ELSE LEAST(chat_rate_limits.count + 1, 61) END,
        window_start = CASE WHEN chat_rate_limits.window_start <= clock_timestamp() - interval '1 minute'
          THEN clock_timestamp() ELSE chat_rate_limits.window_start END
      RETURNING count`, [sender.id]);
    if (quota[0].count > 60) throw new HttpException('訊息太頻繁，請稍後再試', 429);

    try {
      const saved = await this.msgRepo.save(this.msgRepo.create({
        chatId,
        senderId: sender.id,
        content: dto.content.trim(),
        type: dto.type ?? MessageType.TEXT,
        clientMessageId: dto.client_message_id ?? null,
      }));
      await this.chatRepo.update(chatId, { updatedAt: new Date() });
      saved.sender = sender;
      this.background(() =>
        this.chatPush.newMessage(chat, saved, sender, (userId) => this.unreadTotalForUser(userId)),
      );
      return saved;
    } catch (error) {
      if (dto.client_message_id && this.isUniqueViolation(error)) {
        const existing = await this.msgRepo.findOne({
          where: { chatId, senderId: sender.id, clientMessageId: dto.client_message_id },
          relations: ['sender'],
        });
        if (existing) return existing;
      }
      throw error;
    }
  }

  /** 只把已經載入、且不晚於指定訊息的對方訊息標成已讀。 */
  async markRead(chatId: string, userId: string, upToMessageId: string): Promise<void> {
    await this.assertParticipant(chatId, userId);
    if (!isUuid(upToMessageId)) throw new BadRequestException('已讀範圍不正確');
    const pivot = await this.msgRepo.findOne({ where: { id: upToMessageId, chatId } });
    if (!pivot) throw new BadRequestException('已讀範圍不正確');
    // 同上：pivot.createdAt 被截到毫秒後，最新那則（微秒較大）永遠不會 <= 它，未讀就一直停在 1。
    await this.msgRepo
      .createQueryBuilder()
      .update(Message)
      .set({ readAt: new Date() })
      .where(
        `chat_id = :chatId AND sender_id != :userId AND read_at IS NULL
          AND created_at <= (SELECT p.created_at FROM messages p WHERE p.id = :pivotId)`,
        { chatId, userId, pivotId: pivot.id },
      )
      .execute();
  }

  async assertParticipant(chatId: string, userId: string): Promise<void> {
    if (!isUuid(chatId) || !isUuid(userId)) throw new ForbiddenException('無權限存取此聊天室');
    const count = await this.chatRepo
      .createQueryBuilder('chat')
      .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
      .where('chat.id = :chatId', { chatId })
      .getCount();
    if (count === 0) throw new ForbiddenException('無權限存取此聊天室');
  }

  /** 聊天室的所有參與者 id（給即時事件與上線狀態用）。 */
  async participantIds(chatId: string): Promise<string[]> {
    if (!isUuid(chatId)) return [];
    const rows: Array<{ user_id: string }> = await this.chatRepo.manager.query(
      'SELECT user_id FROM chat_participants WHERE chat_id = $1',
      [chatId],
    );
    return rows.map((row) => row.user_id);
  }

  private async assertNotBlocked(leftId: string, rightId: string): Promise<void> {
    const blocked = await this.blockRepo.findOne({
      where: [
        { blockerId: leftId, blockedId: rightId },
        { blockerId: rightId, blockedId: leftId },
      ],
    });
    if (blocked) throw new ForbiddenException('無法與這個使用者聯絡');
  }

  async detailForUser(id: string, userId: string): Promise<Chat> {
    await this.assertParticipant(id, userId);
    return this.loadChat(id);
  }

  private async loadChat(id: string): Promise<Chat> {
    const chat = await this.chatRepo.findOne({
      where: { id },
      relations: ['participants', 'item', 'qrItem'],
    });
    if (!chat) throw new NotFoundException('聊天室不存在');
    const lastMsgs = await this.msgRepo.find({
      where: { chatId: id },
      order: { createdAt: 'DESC' },
      take: 1,
    });
    (chat as Chat & { messages?: Message[] }).messages = lastMsgs;
    return chat;
  }

  /** 推播不能拖慢或弄壞送訊息：在背景執行，失敗只記錄。 */
  private background(task: () => Promise<void>): void {
    void task().catch((error: unknown) => {
      this.logger.warn(`推播處理失敗：${(error as Error)?.message ?? error}`);
    });
  }

  private isUniqueViolation(error: unknown): boolean {
    return typeof error === 'object' && error != null && (error as { code?: string }).code === '23505';
  }
}
