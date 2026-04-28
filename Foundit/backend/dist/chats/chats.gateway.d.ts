import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ChatsService } from './chats.service';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
export declare class ChatsGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly chatsService;
    private readonly jwtService;
    private readonly userRepo;
    server: Server;
    private readonly logger;
    constructor(chatsService: ChatsService, jwtService: JwtService, userRepo: Repository<User>);
    handleConnection(client: Socket): Promise<void>;
    handleDisconnect(client: Socket): void;
    handleJoin(client: Socket, data: {
        chatId: string;
    }): Promise<{
        event: string;
        chatId: string;
    }>;
    handleMessage(client: Socket, data: {
        chatId: string;
        content: string;
        type?: string;
    }): Promise<Record<string, unknown>>;
    handleRead(client: Socket, data: {
        chatId: string;
    }): Promise<void>;
    pushToChat(chatId: string, event: string, payload: any): void;
    private extractUser;
}
