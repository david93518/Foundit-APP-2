import { Item } from './item.entity';
import { Message } from './message.entity';
import { Notification } from './notification.entity';
import { QrItem } from './qr-item.entity';
export declare class User {
    id: string;
    phone: string;
    googleSub: string | null;
    name: string;
    avatarUrl: string;
    bio: string;
    email: string;
    isVerified: boolean;
    fcmToken: string;
    createdAt: Date;
    updatedAt: Date;
    items: Item[];
    notifications: Notification[];
    qrItems: QrItem[];
    messages: Message[];
}
