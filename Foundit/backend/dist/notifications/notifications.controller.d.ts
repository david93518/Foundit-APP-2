import { NotificationsService } from './notifications.service';
import { User } from '../common/entities/user.entity';
export declare class NotificationsController {
    private readonly notifService;
    constructor(notifService: NotificationsService);
    findAll(user: User, limit?: string, offset?: string): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
    }>;
    unreadCount(user: User): Promise<{
        success: boolean;
        data: {
            count: number;
        };
    }>;
    markRead(id: string, user: User): Promise<{
        success: boolean;
    }>;
    markAllRead(user: User): Promise<{
        success: boolean;
    }>;
}
