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
exports.QrController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const qr_service_1 = require("./qr.service");
const generate_qr_dto_1 = require("./dto/generate-qr.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../common/decorators/current-user.decorator");
const user_entity_1 = require("../common/entities/user.entity");
const user_mobile_serializer_1 = require("../users/user-mobile.serializer");
function toMobileQrItem(q) {
    return {
        id: q.id,
        user_id: q.userId,
        name: q.name,
        description: q.description ?? '',
        qr_code: q.qrCode,
        qr_image_url: q.qrImageUrl ?? '',
        created_at: q.createdAt ? new Date(q.createdAt).getTime() : Date.now(),
    };
}
let QrController = class QrController {
    qrService;
    constructor(qrService) {
        this.qrService = qrService;
    }
    async generate(dto, user) {
        const data = await this.qrService.generate(dto, user);
        return { success: true, data: toMobileQrItem(data) };
    }
    async findAll(user) {
        const data = await this.qrService.findAllByUser(user.id);
        return { success: true, data: data.map(toMobileQrItem) };
    }
    async remove(id, user) {
        await this.qrService.remove(id, user);
        return { success: true, message: '已刪除' };
    }
    async scan(code) {
        const { qrItem, owner } = await this.qrService.scanByCode(code);
        return {
            success: true,
            qr_item: toMobileQrItem(qrItem),
            owner: (0, user_mobile_serializer_1.toMobileUser)(owner),
        };
    }
};
exports.QrController = QrController;
__decorate([
    (0, common_1.Post)('generate'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    (0, swagger_1.ApiOperation)({ summary: '產生 QR Code 防丟貼紙' }),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [generate_qr_dto_1.GenerateQrDto, user_entity_1.User]),
    __metadata("design:returntype", Promise)
], QrController.prototype, "generate", null);
__decorate([
    (0, common_1.Get)('items'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    (0, swagger_1.ApiOperation)({ summary: '取得我的 QR 物品清單' }),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [user_entity_1.User]),
    __metadata("design:returntype", Promise)
], QrController.prototype, "findAll", null);
__decorate([
    (0, common_1.Delete)('items/:id'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    (0, swagger_1.ApiOperation)({ summary: '刪除 QR 物品' }),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, user_entity_1.User]),
    __metadata("design:returntype", Promise)
], QrController.prototype, "remove", null);
__decorate([
    (0, common_1.Get)('scan/:code'),
    (0, swagger_1.ApiOperation)({ summary: '掃描 QR Code（公開端點）' }),
    __param(0, (0, common_1.Param)('code')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], QrController.prototype, "scan", null);
exports.QrController = QrController = __decorate([
    (0, swagger_1.ApiTags)('QR Code'),
    (0, common_1.Controller)('qr'),
    __metadata("design:paramtypes", [qr_service_1.QrService])
], QrController);
//# sourceMappingURL=qr.controller.js.map