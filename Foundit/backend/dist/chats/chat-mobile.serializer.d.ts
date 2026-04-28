import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';
type ChatWithRels = Chat & {
    item?: Item | null;
    participants?: User[];
    messages?: Message[];
    unreadCount?: number;
    lastMessage?: Message | null;
};
type MessageWithSender = Message & {
    sender?: User | null;
};
export declare function toMobileMessage(msg: MessageWithSender): Record<string, unknown>;
export declare function toMobileChat(chat: ChatWithRels, currentUserId: string): Record<string, unknown>;
export {};
