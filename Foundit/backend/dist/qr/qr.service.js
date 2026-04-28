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
exports.QrService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const config_1 = require("@nestjs/config");
const uuid_1 = require("uuid");
const qr_item_entity_1 = require("../common/entities/qr-item.entity");
let QrService = class QrService {
    qrRepo;
    config;
    constructor(qrRepo, config) {
        this.qrRepo = qrRepo;
        this.config = config;
    }
    async generate(dto, user) {
        const code = (0, uuid_1.v4)();
        const baseUrl = this.config.get('APP_BASE_URL', 'http://localhost:3000');
        const qrCode = `${baseUrl}/qr/${code}`;
        const qrItem = this.qrRepo.create({
            userId: user.id,
            name: dto.name,
            description: dto.description ?? '',
            qrCode,
            qrImageUrl: '',
        });
        return this.qrRepo.save(qrItem);
    }
    async findAllByUser(userId) {
        return this.qrRepo.find({
            where: { userId },
            order: { createdAt: 'DESC' },
        });
    }
    async remove(id, user) {
        const qrItem = await this.qrRepo.findOne({ where: { id } });
        if (!qrItem)
            throw new common_1.NotFoundException('QR 物品不存在');
        if (qrItem.userId !== user.id)
            throw new common_1.ForbiddenException('無權限刪除此 QR');
        await this.qrRepo.remove(qrItem);
    }
    async scanByCode(code) {
        const baseUrl = this.config.get('APP_BASE_URL', 'http://localhost:3000');
        const qrCode = `${baseUrl}/qr/${code}`;
        const qrItem = await this.qrRepo.findOne({
            where: { qrCode },
            relations: ['user'],
        });
        if (!qrItem)
            throw new common_1.NotFoundException('QR Code 無效或已刪除');
        return { qrItem, owner: qrItem.user };
    }
};
exports.QrService = QrService;
exports.QrService = QrService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(qr_item_entity_1.QrItem)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        config_1.ConfigService])
], QrService);
//# sourceMappingURL=qr.service.js.map