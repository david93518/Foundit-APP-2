import { User } from './user.entity';
import { PointEvent } from './point-event.entity';
export declare class UserPoints {
    id: string;
    userId: string;
    user: User;
    points: number;
    createdAt: Date;
    updatedAt: Date;
    events: PointEvent[];
}
