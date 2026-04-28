"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PointsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_points_entity_1 = require("../common/entities/user-points.entity");
const point_event_entity_1 = require("../common/entities/point-event.entity");
const POINT_VALUES = {
    [point_event_entity_1.PointEventType.FOUND_ITEM]: 50,
    [point_event_entity_1.PointEventType.MATCH_SUCCESS]: 100,
    [point_event_entity_1.PointEventType.DAILY_LOGIN]: 5,
    [point_event_entity_1.PointEventType.QR_SCAN]: 20,
    [point_event_entity_1.PointEventType.REWARD_RECEIVED]: 0,
};
let PointsService = class PointsService {
    pointsRepo;
    eventRepo;
    constructor(pointsRepo, eventRepo) {
        this.pointsRepo = pointsRepo;
        this.eventRepo = eventRepo;
    }
    async getPoints(userId) {
        const userPoints = await this.getOrCreate(userId);
        const history = await this.eventRepo.find({
            where: { userPointsId: userPoints.id },
            order: { createdAt: 'DESC' },
            take: 50,
        });
        return { points: userPoints.points, history };
    }
    async addPoints(userId, type, description, customPoints) {
        const userPoints = await this.getOrCreate(userId);
        const pts = customPoints ?? POINT_VALUES[type] ?? 0;
        if (pts === 0)
            return;
        userPoints.points += pts;
        await this.pointsRepo.save(userPoints);
        await this.eventRepo.save(this.eventRepo.create({
            userPointsId: userPoints.id,
            type,
            points: pts,
            description,
        }));
    }
    async getLeaderboard(limit = 20) {
        return this.pointsRepo.find({
            relations: ['user'],
            order: { points: 'DESC' },
            take: limit,
        });
    }
    async getOrCreate(userId) {
        let up = await this.pointsRepo.findOne({ where: { userId } });
        if (!up) {
            up = await this.pointsRepo.save(this.pointsRepo.create({ userId, points: 0 }));
        }
        return up;
    }
};
exports.PointsService = PointsService;
exports.PointsService = PointsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_points_entity_1.UserPoints)),
    __param(1, (0, typeorm_1.InjectRepository)(point_event_entity_1.PointEvent)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], PointsService);
//# sourceMappingURL=points.service.js.map