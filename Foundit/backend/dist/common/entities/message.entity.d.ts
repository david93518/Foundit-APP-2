import { User } from './user.entity';
import { Chat } from './chat.entity';
export declare enum MessageType {
    TEXT = "TEXT",
    IMAGE = "IMAGE",
    LOCATION = "LOCATION",
    SYSTEM = "SYSTEM"
}
export declare class Message {
    id: string;
    chatId: string;
    chat: Chat;
    senderId: string;
    sender: User;
    content: string;
    type: MessageType;
    readAt: Date | null;
    createdAt: Date;
}
