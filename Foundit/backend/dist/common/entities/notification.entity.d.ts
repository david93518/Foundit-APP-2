import { User } from './user.entity';
export declare enum NotificationType {
    AI_MATCH = "AI_MATCH",
    NEW_MESSAGE = "NEW_MESSAGE",
    NEARBY_ITEM = "NEARBY_ITEM",
    QR_SCAN = "QR_SCAN",
    REWARD = "REWARD",
    SYSTEM = "SYSTEM"
}
export declare class Notification {
    id: string;
    userId: string;
    user: User;
    type: NotificationType;
    title: string;
    content: string;
    itemId: string | null;
    chatId: string | null;
    isRead: boolean;
    createdAt: Date;
}
