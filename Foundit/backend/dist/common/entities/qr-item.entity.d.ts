import { User } from './user.entity';
export declare class QrItem {
    id: string;
    userId: string;
    user: User;
    name: string;
    description: string;
    qrCode: string;
    qrImageUrl: string;
    createdAt: Date;
}
