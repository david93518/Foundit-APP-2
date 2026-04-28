import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { ItemsService } from '../items/items.service';
export interface UserStats {
    posted: number;
    helpful: number;
    bookmarks: number;
    found_count: number;
    lost_count: number;
}
export interface BadgeInfo {
    code: string;
    name: string;
    emoji: string;
    unlocked: boolean;
    progress: number;
    description: string;
}
export interface UpdateProfilePayload {
    name?: string;
    avatarUrl?: string;
    bio?: string;
    email?: string;
}
export declare class UsersService {
    private readonly userRepo;
    private readonly itemsService;
    constructor(userRepo: Repository<User>, itemsService: ItemsService);
    getMe(userId: string): Promise<User>;
    updateProfile(userId: string, payload: UpdateProfilePayload): Promise<User>;
    getMyItems(userId: string): Promise<import("../common/entities/item.entity").Item[]>;
    getStats(userId: string): Promise<UserStats>;
    getBadges(userId: string): Promise<BadgeInfo[]>;
    private badge;
}
