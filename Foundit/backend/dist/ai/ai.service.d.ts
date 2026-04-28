import { ItemsService } from '../items/items.service';
import { Item, ItemType } from '../common/entities/item.entity';
export interface MatchResult {
    item: Item;
    score: number;
    similarityPercent: number;
}
export declare class AiService {
    private readonly itemsService;
    constructor(itemsService: ItemsService);
    match(params: {
        itemId?: string;
        imageUrl?: string;
        type?: ItemType;
        keyword?: string;
    }): Promise<MatchResult[]>;
    private calculateScore;
    private extractKeywords;
}
