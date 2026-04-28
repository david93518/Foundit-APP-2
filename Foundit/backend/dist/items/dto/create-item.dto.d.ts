import { ItemType } from '../../common/entities/item.entity';
export declare class CreateItemDto {
    type: ItemType;
    title: string;
    category: string;
    description?: string;
    color: string;
    images?: string[];
    latitude?: number;
    longitude?: number;
    locationName?: string;
    lostAt?: number;
    reward?: number;
    hasReward?: boolean;
    storageLocation?: string;
    handedToPolice?: boolean;
}
