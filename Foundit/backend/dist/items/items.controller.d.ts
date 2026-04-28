import { ItemsService } from './items.service';
import { CreateItemDto } from './dto/create-item.dto';
import { QueryItemDto } from './dto/query-item.dto';
import { User } from '../common/entities/user.entity';
export declare class ItemsController {
    private readonly itemsService;
    constructor(itemsService: ItemsService);
    findAll(query: QueryItemDto): Promise<{
        success: boolean;
        data: Record<string, unknown>[];
        total: number;
        hasMore: boolean;
    }>;
    stats(): Promise<{
        success: boolean;
        data: {
            total_active: number;
            total_resolved: number;
            total_lost: number;
            total_found: number;
            by_category: Record<string, number>;
        };
    }>;
    findOne(id: string): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    create(dto: CreateItemDto, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    update(id: string, dto: Partial<CreateItemDto>, user: User): Promise<{
        success: boolean;
        data: Record<string, unknown>;
    }>;
    remove(id: string, user: User): Promise<{
        success: boolean;
        message: string;
    }>;
    resolve(id: string, user: User): Promise<{
        success: boolean;
        message: string;
    }>;
}
