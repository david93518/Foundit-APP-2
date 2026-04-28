import { UserPoints } from './user-points.entity';
export declare enum PointEventType {
    FOUND_ITEM = "found_item",
    MATCH_SUCCESS = "match_success",
    DAILY_LOGIN = "daily_login",
    QR_SCAN = "qr_scan",
    REWARD_RECEIVED = "reward_received"
}
export declare class PointEvent {
    id: string;
    userPointsId: string;
    userPoints: UserPoints;
    type: PointEventType;
    points: number;
    description: string;
    createdAt: Date;
}
