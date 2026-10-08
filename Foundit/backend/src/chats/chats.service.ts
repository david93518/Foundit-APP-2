import {
  BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
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
    const page = Math.max(options.page ?? 1, 1);
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
      qb.andWhere('(m.createdAt < :before OR (m.createdAt = :before AND m.id < :beforeId))', {
        before: pivot.createdAt,
        beforeId: pivot.id,
      });
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
    if (dto.client_message_id) {
      const existing = await this.msgRepo.findOne({
        where: { chatId, senderId: sender.id, clientMessageId: dto.client_message_id },
        relations: ['sender'],
      });
      if (existing) return existing;
    }

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
    await this.msgRepo
      .createQueryBuilder()
      .update(Message)
      .set({ readAt: new Date() })
      .where(
        'chat_id = :chatId AND sender_id != :userId AND read_at IS NULL AND created_at <= :createdAt',
        { chatId, userId, createdAt: pivot.createdAt },
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

  private async assertNotBlocked(leftId: string, rightId: string): Promise<void> {
    const blocked = await this.blockRepo.findOne({
      where: [
        { blockerId: leftId, blockedId: rightId },
        { blockerId: rightId, blockedId: leftId },
      ],
    });
    if (blocked) throw new ForbiddenException('無法與這個使用者聯絡');
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
