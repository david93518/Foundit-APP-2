import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { CreateChatDto } from './dto/create-chat.dto';
import { SendMessageDto } from './dto/send-message.dto';
import { User } from '../common/entities/user.entity';
export declare class ChatsController {
    private readonly chatsService;
    private readonly chatsGateway;
    constructor(chatsService: ChatsService, chatsGateway: ChatsGateway);
    create(dto: CreateChatDto, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    findAll(user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
    }>;
    unreadCount(user: User): Promise<{
        success: boolean;
        data: {
            count: number;
        };
    }>;
    getMessages(id: string, user: User, page: number, pageSize: number): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
    }>;
    sendMessage(id: string, dto: SendMessageDto, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    markRead(id: string, user: User): Promise<{
        success: boolean;
    }>;
}
