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
var SeedService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SeedService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const item_entity_1 = require("../common/entities/item.entity");
const user_entity_1 = require("../common/entities/user.entity");
const user_points_entity_1 = require("../common/entities/user-points.entity");
let SeedService = SeedService_1 = class SeedService {
    itemRepo;
    userRepo;
    pointsRepo;
    log = new common_1.Logger(SeedService_1.name);
    constructor(itemRepo, userRepo, pointsRepo) {
        this.itemRepo = itemRepo;
        this.userRepo = userRepo;
        this.pointsRepo = pointsRepo;
    }
    async onModuleInit() {
        if (process.env.SEED_SAMPLE_DATA === 'false') {
            this.log.log('已設定 SEED_SAMPLE_DATA=false，略過示範資料');
            return;
        }
        try {
            const existing = await this.itemRepo.count();
            if (existing > 0) {
                this.log.log(`已有 ${existing} 筆物品，略過 seed`);
                return;
            }
            let demoUser = await this.userRepo.findOne({ where: { phone: '0900000000' } });
            if (!demoUser) {
                demoUser = await this.userRepo.save(this.userRepo.create({
                    phone: '0900000000',
                    name: '示範用戶',
                    avatarUrl: '',
                    isVerified: true,
                }));
                await this.pointsRepo.save(this.pointsRepo.create({ userId: demoUser.id, points: 0 }));
                this.log.log('已建立示範用戶 0900000000');
            }
            const now = Date.now();
            const samples = [
                {
                    type: item_entity_1.ItemType.LOST,
                    userId: demoUser.id,
                    title: '黑色真皮長夾（示範）',
                    category: '錢包/皮夾',
                    description: '此為資料庫 seed 示範，可刪除。',
                    color: '黑色',
                    images: [
                        'https://images.unsplash.com/photo-1627123424-af7-4a07-a9df-fa71b9a898a8?w=400&q=80&auto=format',
                    ],
                    latitude: 25.0415,
                    longitude: 121.5514,
                    locationName: '台北市大安區（示範）',
                    lostAt: new Date(now - 86400000 * 2),
                    reward: 500,
                    hasReward: true,
                    storageLocation: '',
                    handedToPolice: false,
                    status: item_entity_1.ItemStatus.ACTIVE,
                },
                {
                    type: item_entity_1.ItemType.FOUND,
                    userId: demoUser.id,
                    title: '拾得悠遊卡一張（示範）',
                    category: '其他',
                    description: '此為資料庫 seed 示範，可刪除。',
                    color: '藍色',
                    images: [
                        'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&q=80&auto=format',
                    ],
                    latitude: 25.033,
                    longitude: 121.5654,
                    locationName: '台北車站（示範）',
                    lostAt: new Date(now - 3600000 * 5),
                    reward: 0,
                    hasReward: false,
                    storageLocation: '服務台',
                    handedToPolice: false,
                    status: item_entity_1.ItemStatus.ACTIVE,
                },
            ];
            for (const row of samples) {
                await this.itemRepo.save(this.itemRepo.create(row));
            }
            this.log.log(`已寫入 ${samples.length} 筆示範物品（可於 App 或 DB 刪除）`);
        }
        catch (e) {
            this.log.warn(`Seed 略過或失敗（資料庫未就緒時屬正常）: ${e.message}`);
        }
    }
};
exports.SeedService = SeedService;
exports.SeedService = SeedService = SeedService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(item_entity_1.Item)),
    __param(1, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(2, (0, typeorm_1.InjectRepository)(user_points_entity_1.UserPoints)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SeedService);
//# sourceMappingURL=seed.service.js.map