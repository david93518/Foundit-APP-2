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
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_entity_1 = require("../common/entities/user.entity");
const items_service_1 = require("../items/items.service");
const item_entity_1 = require("../common/entities/item.entity");
let UsersService = class UsersService {
    userRepo;
    itemsService;
    constructor(userRepo, itemsService) {
        this.userRepo = userRepo;
        this.itemsService = itemsService;
    }
    async getMe(userId) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user)
            throw new common_1.NotFoundException('用戶不存在');
        return user;
    }
    async updateProfile(userId, payload) {
        const user = await this.getMe(userId);
        if (payload.name !== undefined && payload.name.length > 0) {
            user.name = payload.name;
        }
        if (payload.avatarUrl !== undefined)
            user.avatarUrl = payload.avatarUrl;
        if (payload.bio !== undefined)
            user.bio = payload.bio;
        if (payload.email !== undefined)
            user.email = payload.email;
        return this.userRepo.save(user);
    }
    async getMyItems(userId) {
        return this.itemsService.findByUser(userId);
    }
    async getStats(userId) {
        const [posted, helpful, foundCount, lostCount] = await Promise.all([
            this.itemsService.countByUser(userId),
            this.itemsService.countResolvedByUser(userId),
            this.itemsService.countByUserAndType(userId, item_entity_1.ItemType.FOUND),
            this.itemsService.countByUserAndType(userId, item_entity_1.ItemType.LOST),
        ]);
        return {
            posted,
            helpful,
            bookmarks: 0,
            found_count: foundCount,
            lost_count: lostCount,
        };
    }
    async getBadges(userId) {
        const stats = await this.getStats(userId);
        const user = await this.getMe(userId);
        const accountDays = Math.floor((Date.now() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24));
        const list = [
            this.badge('helpful_citizen', '熱心公民', '🎖️', '完成第一次成功幫助', stats.helpful >= 1, Math.min(stats.helpful / 1, 1)),
            this.badge('picker_10', '撿到 10 件', '🏆', '張貼 10 件以上「拾獲」物品', stats.found_count >= 10, Math.min(stats.found_count / 10, 1)),
            this.badge('treasure_hunter', '尋寶達人', '🔍', '張貼 5 件以上「遺失」物品', stats.lost_count >= 5, Math.min(stats.lost_count / 5, 1)),
            this.badge('kind_soul', '善心人士', '💚', '成功幫助 5 次以上', stats.helpful >= 5, Math.min(stats.helpful / 5, 1)),
            this.badge('streak_30', '連續 30 天', '🔥', '帳號使用滿 30 天', accountDays >= 30, Math.min(accountDays / 30, 1)),
        ];
        return list;
    }
    badge(code, name, emoji, description, unlocked, progress) {
        return { code, name, emoji, unlocked, progress, description };
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        items_service_1.ItemsService])
], UsersService);
//# sourceMappingURL=users.service.js.map