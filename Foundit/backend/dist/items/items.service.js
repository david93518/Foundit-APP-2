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
exports.ItemsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const item_entity_1 = require("../common/entities/item.entity");
let ItemsService = class ItemsService {
    itemRepo;
    constructor(itemRepo) {
        this.itemRepo = itemRepo;
    }
    async findAll(query) {
        const page = query.page ?? 1;
        const pageSize = Math.min(query.page_size ?? 20, 50);
        const qb = this.itemRepo
            .createQueryBuilder('item')
            .leftJoinAndSelect('item.user', 'user')
            .where('item.status = :status', { status: item_entity_1.ItemStatus.ACTIVE });
        this.applyFilters(qb, query);
        qb.orderBy('item.createdAt', 'DESC')
            .skip((page - 1) * pageSize)
            .take(pageSize);
        const [data, total] = await qb.getManyAndCount();
        return { data, total, hasMore: page * pageSize < total };
    }
    async findOne(id) {
        const item = await this.itemRepo.findOne({
            where: { id },
            relations: ['user'],
        });
        if (!item)
            throw new common_1.NotFoundException('物品不存在');
        return item;
    }
    async create(dto, user) {
        const item = this.itemRepo.create({
            ...dto,
            userId: user.id,
            images: dto.images ?? [],
            lostAt: dto.lostAt ? new Date(dto.lostAt) : new Date(),
        });
        const saved = await this.itemRepo.save(item);
        saved.user = user;
        return saved;
    }
    async update(id, dto, user) {
        const item = await this.findOne(id);
        if (item.userId !== user.id)
            throw new common_1.ForbiddenException('無權限修改此物品');
        const { lostAt, ...rest } = dto;
        const updateData = { ...rest };
        if (lostAt)
            updateData.lostAt = new Date(lostAt);
        Object.assign(item, updateData);
        return this.itemRepo.save(item);
    }
    async remove(id, user) {
        const item = await this.findOne(id);
        if (item.userId !== user.id)
            throw new common_1.ForbiddenException('無權限刪除此物品');
        await this.itemRepo.remove(item);
    }
    async resolve(id, user) {
        const item = await this.findOne(id);
        if (item.userId !== user.id)
            throw new common_1.ForbiddenException('無權限操作此物品');
        item.status = item_entity_1.ItemStatus.RESOLVED;
        await this.itemRepo.save(item);
    }
    async findByUser(userId) {
        return this.itemRepo.find({
            where: { userId },
            relations: ['user'],
            order: { createdAt: 'DESC' },
        });
    }
    async countByUser(userId) {
        return this.itemRepo.count({ where: { userId } });
    }
    async countResolvedByUser(userId) {
        return this.itemRepo.count({
            where: { userId, status: item_entity_1.ItemStatus.RESOLVED },
        });
    }
    async countByUserAndType(userId, type) {
        return this.itemRepo.count({ where: { userId, type } });
    }
    async getStats() {
        const [statusRows, typeRows, categoryRows] = await Promise.all([
            this.itemRepo
                .createQueryBuilder('item')
                .select('item.status', 'status')
                .addSelect('COUNT(*)', 'count')
                .groupBy('item.status')
                .getRawMany(),
            this.itemRepo
                .createQueryBuilder('item')
                .select('item.type', 'type')
                .addSelect('COUNT(*)', 'count')
                .where('item.status = :status', { status: item_entity_1.ItemStatus.ACTIVE })
                .groupBy('item.type')
                .getRawMany(),
            this.itemRepo
                .createQueryBuilder('item')
                .select('item.category', 'category')
                .addSelect('COUNT(*)', 'count')
                .where('item.status = :status', { status: item_entity_1.ItemStatus.ACTIVE })
                .groupBy('item.category')
                .getRawMany(),
        ]);
        const statusMap = Object.fromEntries(statusRows.map((r) => [r.status, Number(r.count)]));
        const typeMap = Object.fromEntries(typeRows.map((r) => [r.type, Number(r.count)]));
        const byCategory = {};
        for (const r of categoryRows) {
            byCategory[r.category] = Number(r.count);
        }
        return {
            total_active: statusMap[item_entity_1.ItemStatus.ACTIVE] ?? 0,
            total_resolved: statusMap[item_entity_1.ItemStatus.RESOLVED] ?? 0,
            total_lost: typeMap['LOST'] ?? 0,
            total_found: typeMap['FOUND'] ?? 0,
            by_category: byCategory,
        };
    }
    async findForMatch(excludeItemId, keywords) {
        const qb = this.itemRepo
            .createQueryBuilder('item')
            .leftJoinAndSelect('item.user', 'user')
            .where('item.status = :status', { status: item_entity_1.ItemStatus.ACTIVE })
            .andWhere('item.id != :id', { id: excludeItemId });
        if (keywords.length > 0) {
            const conditions = keywords.map((_, i) => `(item.title ILIKE :kw${i} OR item.description ILIKE :kw${i})`);
            const params = {};
            keywords.forEach((kw, i) => (params[`kw${i}`] = `%${kw}%`));
            qb.andWhere(`(${conditions.join(' OR ')})`, params);
        }
        return qb.limit(10).getMany();
    }
    applyFilters(qb, query) {
        if (query.type) {
            qb.andWhere('item.type = :type', { type: query.type });
        }
        if (query.category) {
            qb.andWhere('item.category = :category', { category: query.category });
        }
        if (query.keyword) {
            qb.andWhere('(item.title ILIKE :kw OR item.description ILIKE :kw)', { kw: `%${query.keyword}%` });
        }
        if (query.has_reward) {
            qb.andWhere('item.has_reward = true');
        }
        if (query.date_from) {
            qb.andWhere('item.lost_at >= :dateFrom', { dateFrom: new Date(query.date_from) });
        }
        if (query.date_to) {
            qb.andWhere('item.lost_at <= :dateTo', { dateTo: new Date(query.date_to) });
        }
        if (query.lat && query.lng && query.radius) {
            qb.andWhere(`(6371 * acos(cos(radians(:lat)) * cos(radians(CAST(item.latitude AS FLOAT))) * cos(radians(CAST(item.longitude AS FLOAT)) - radians(:lng)) + sin(radians(:lat)) * sin(radians(CAST(item.latitude AS FLOAT))))) < :radius`, { lat: query.lat, lng: query.lng, radius: query.radius });
        }
    }
};
exports.ItemsService = ItemsService;
exports.ItemsService = ItemsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(item_entity_1.Item)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], ItemsService);
//# sourceMappingURL=items.service.js.map