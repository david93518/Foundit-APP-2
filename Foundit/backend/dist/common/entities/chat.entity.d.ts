import { User } from './user.entity';
import { Item } from './item.entity';
import { Message } from './message.entity';
export declare class Chat {
    id: string;
    itemId: string;
    item: Item;
    participants: User[];
    messages: Message[];
    createdAt: Date;
    updatedAt: Date;
}
