import { Repository } from 'typeorm';
import { Notification, NotificationType } from '../common/entities/notification.entity';
export declare class NotificationsService {
    private readonly notifRepo;
    constructor(notifRepo: Repository<Notification>);
    findAllByUser(userId: string, take?: number, skip?: number): Promise<Notification[]>;
    unreadCountForUser(userId: string): Promise<number>;
    markRead(id: string, userId: string): Promise<void>;
    markAllRead(userId: string): Promise<void>;
    create(params: {
        userId: string;
        type: NotificationType;
        title: string;
        content: string;
        itemId?: string;
        chatId?: string;
    }): Promise<Notification>;
}
