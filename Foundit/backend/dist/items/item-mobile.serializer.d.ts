import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
type ItemWithUser = Item & {
    user?: User | null;
};
export declare function toMobileItem(item: ItemWithUser): Record<string, unknown>;
export {};
