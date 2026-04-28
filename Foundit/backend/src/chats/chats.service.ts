import {
  Injectable, NotFoundException, ForbiddenException, BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Chat } from '../common/entities/chat.entity';
import { Message, MessageType } from '../common/entities/message.entity';
import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';

@Injectable()
export class ChatsService {
  constructor(
    @InjectRepository(Chat) private readonly chatRepo: Repository<Chat>,
    @InjectRepository(Message) private readonly msgRepo: Repository<Message>,
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
  ) {}

  async createOrGet(dto: CreateChatDto, requester: User): Promise<Chat> {
    const item = await this.itemRepo.findOne({
      where: { id: dto.item_id },
      relations: ['user'],
    });
    if (!item) throw new NotFoundException('物品不存在');
    if (item.userId === requester.id) {
      throw new BadRequestException('不能和自己的物品開啟聊天');
    }

    // 找既有的聊天室（同一物品、同一請求者）
    const existing = await this.chatRepo
      .createQueryBuilder('chat')
      .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: requester.id })
      .where('chat.item_id = :itemId', { itemId: dto.item_id })
      .getOne();

    if (existing) return this.loadChat(existing.id);

    const chat = this.chatRepo.create({ itemId: dto.item_id });
    chat.participants = [requester, item.user];
    const saved = await this.chatRepo.save(chat);

    // 系統訊息
    await this.msgRepo.save(
      this.msgRepo.create({
        chatId: saved.id,
        senderId: requester.id,
        content: `${requester.name} 就「${item.title}」發起聯絡`,
        type: MessageType.SYSTEM,
      }),
    );

    return this.loadChat(saved.id);
  }

  async findAllForUser(
    userId: string,
  ): Promise<Array<Chat & { unreadCount: number; lastMessage: Message | null }>> {
    const chats = await this.chatRepo
      .createQueryBuilder('chat')
      .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
      .leftJoinAndSelect('chat.participants', 'participant')
      .leftJoinAndSelect('chat.item', 'item')
      .orderBy('chat.updated_at', 'DESC')
      .getMany();

    if (chats.length === 0) return [];

    const chatIds = chats.map((c) => c.id);

    // 平行取每個 chat 的最後一條訊息與未讀數
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
    lastMsgs.forEach((m) => lastByChat.set(m.chatId, m));
    const unreadByChat = new Map<string, number>();
    unreadRows.forEach((r) => unreadByChat.set(r.chat_id, Number(r.count)));

    return chats.map((c) =>
      Object.assign(c, {
        unreadCount: unreadByChat.get(c.id) ?? 0,
        lastMessage: lastByChat.get(c.id) ?? null,
      }),
    );
  }

  /** 我的全部對話累積未讀數 — 給底部 nav badge 用 */
  async unreadTotalForUser(userId: string): Promise<number> {
    const result = await this.msgRepo
      .createQueryBuilder('m')
      .innerJoin('chat_participants', 'cp', 'cp.chat_id = m.chat_id')
      .where('cp.user_id = :uid', { uid: userId })
      .andWhere('m.sender_id != :uid', { uid: userId })
      .andWhere('m.read_at IS NULL')
      .getCount();
    return result;
  }

  async getMessages(chatId: string, userId: string, page = 1, pageSize = 50): Promise<Message[]> {
    await this.assertParticipant(chatId, userId);
    return this.msgRepo.find({
      where: { chatId },
      order: { createdAt: 'ASC' },
      skip: (page - 1) * pageSize,
      take: pageSize,
      relations: ['sender'],
    });
  }

  async sendMessage(chatId: string, dto: SendMessageDto, sender: User): Promise<Message> {
    await this.assertParticipant(chatId, sender.id);
    const msg = this.msgRepo.create({
      chatId,
      senderId: sender.id,
      content: dto.content,
      type: dto.type ?? MessageType.TEXT,
    });
    const saved = await this.msgRepo.save(msg);
    // 更新聊天室 updated_at
    await this.chatRepo.update(chatId, { updatedAt: new Date() } as any);
    saved.sender = sender;
    return saved;
  }

  async markRead(chatId: string, userId: string): Promise<void> {
    await this.assertParticipant(chatId, userId);
    await this.msgRepo
      .createQueryBuilder()
      .update(Message)
      .set({ readAt: new Date() })
      .where('chat_id = :chatId AND sender_id != :userId AND read_at IS NULL', { chatId, userId })
      .execute();
  }

  private async assertParticipant(chatId: string, userId: string): Promise<void> {
    const count = await this.chatRepo
      .createQueryBuilder('chat')
      .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
      .where('chat.id = :chatId', { chatId })
      .getCount();
    if (count === 0) throw new ForbiddenException('無權限存取此聊天室');
  }

  private async loadChat(id: string): Promise<Chat> {
    const chat = await this.chatRepo.findOne({
      where: { id },
      relations: ['participants', 'item'],
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
}
