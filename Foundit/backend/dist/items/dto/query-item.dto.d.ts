import { ItemType } from '../../common/entities/item.entity';
export declare class QueryItemDto {
    type?: ItemType;
    category?: string;
    area?: string;
    keyword?: string;
    has_reward?: boolean;
    date_from?: number;
    date_to?: number;
    lat?: number;
    lng?: number;
    radius?: number;
    page?: number;
    page_size?: number;
}
