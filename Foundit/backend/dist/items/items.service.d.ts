import { Repository } from 'typeorm';
import { Item, ItemType } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { CreateItemDto } from './dto/create-item.dto';
import { QueryItemDto } from './dto/query-item.dto';
export declare class ItemsService {
    private readonly itemRepo;
    constructor(itemRepo: Repository<Item>);
    findAll(query: QueryItemDto): Promise<{
        data: Item[];
        total: number;
        hasMore: boolean;
    }>;
    findOne(id: string): Promise<Item>;
    create(dto: CreateItemDto, user: User): Promise<Item>;
    update(id: string, dto: Partial<CreateItemDto>, user: User): Promise<Item>;
    remove(id: string, user: User): Promise<void>;
    resolve(id: string, user: User): Promise<void>;
    findByUser(userId: string): Promise<Item[]>;
    countByUser(userId: string): Promise<number>;
    countResolvedByUser(userId: string): Promise<number>;
    countByUserAndType(userId: string, type: ItemType): Promise<number>;
    getStats(): Promise<{
        total_active: number;
        total_resolved: number;
        total_lost: number;
        total_found: number;
        by_category: Record<string, number>;
    }>;
    findForMatch(excludeItemId: string, keywords: string[]): Promise<Item[]>;
    private applyFilters;
}
