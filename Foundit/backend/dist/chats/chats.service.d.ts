import { Repository } from 'typeorm';
import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
export declare class ChatsService {
    private readonly chatRepo;
    private readonly msgRepo;
    private readonly itemRepo;
    constructor(chatRepo: Repository<Chat>, msgRepo: Repository<Message>, itemRepo: Repository<Item>);
    createOrGet(dto: CreateChatDto, requester: User): Promise<Chat>;
    findAllForUser(userId: string): Promise<Array<Chat & {
        unreadCount: number;
        lastMessage: Message | null;
    }>>;
    unreadTotalForUser(userId: string): Promise<number>;
    getMessages(chatId: string, userId: string, page?: number, pageSize?: number): Promise<Message[]>;
    sendMessage(chatId: string, dto: SendMessageDto, sender: User): Promise<Message>;
    markRead(chatId: string, userId: string): Promise<void>;
    private assertParticipant;
    private loadChat;
}
