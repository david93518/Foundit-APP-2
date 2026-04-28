import { PointsService } from './points.service';
import { User } from '../common/entities/user.entity';
export declare class PointsController {
    private readonly pointsService;
    constructor(pointsService: PointsService);
    getMyPoints(user: User): Promise<{
        points: number;
        history: import("../common/entities/point-event.entity").PointEvent[];
        success: boolean;
    }>;
    getLeaderboard(): Promise<{
        success: boolean;
        data: import("../common/entities/user-points.entity").UserPoints[];
    }>;
}
