import { UsersService } from './users.service';
import { User } from '../common/entities/user.entity';
declare class UpdateProfileDto {
    name?: string;
    avatar_url?: string;
    bio?: string;
    email?: string;
}
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    getMe(user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    updateProfile(dto: UpdateProfileDto, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    getMyItems(user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
    }>;
    getStats(user: User): Promise<{
        success: boolean;
        data: import("./users.service").UserStats;
    }>;
    getBadges(user: User): Promise<{
        success: boolean;
        data: import("./users.service").BadgeInfo[];
    }>;
}
export {};
