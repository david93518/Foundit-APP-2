import { User } from './user.entity';
import { Chat } from './chat.entity';
export declare enum ItemType {
    LOST = "LOST",
    FOUND = "FOUND"
}
export declare enum ItemStatus {
    ACTIVE = "ACTIVE",
    RESOLVED = "RESOLVED",
    CLOSED = "CLOSED"
}
export declare class Item {
    id: string;
    type: ItemType;
    userId: string;
    user: User;
    title: string;
    category: string;
    description: string;
    color: string;
    images: string[];
    latitude: number;
    longitude: number;
    locationName: string;
    lostAt: Date;
    reward: number;
    hasReward: boolean;
    storageLocation: string;
    handedToPolice: boolean;
    status: ItemStatus;
    createdAt: Date;
    updatedAt: Date;
    chats: Chat[];
}
