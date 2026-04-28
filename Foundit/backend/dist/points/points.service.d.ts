import { Repository } from 'typeorm';
import { UserPoints } from '../common/entities/user-points.entity';
import { PointEvent, PointEventType } from '../common/entities/point-event.entity';
export declare class PointsService {
    private readonly pointsRepo;
    private readonly eventRepo;
    constructor(pointsRepo: Repository<UserPoints>, eventRepo: Repository<PointEvent>);
    getPoints(userId: string): Promise<{
        points: number;
        history: PointEvent[];
    }>;
    addPoints(userId: string, type: PointEventType, description: string, customPoints?: number): Promise<void>;
    getLeaderboard(limit?: number): Promise<UserPoints[]>;
    private getOrCreate;
}
