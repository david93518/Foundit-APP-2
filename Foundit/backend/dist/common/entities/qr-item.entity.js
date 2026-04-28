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
Object.defineProperty(exports, "__esModule", { value: true });
exports.QrItem = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("./user.entity");
let QrItem = class QrItem {
    id;
    userId;
    user;
    name;
    description;
    qrCode;
    qrImageUrl;
    createdAt;
};
exports.QrItem = QrItem;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], QrItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", String)
], QrItem.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, (user) => user.qrItems),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], QrItem.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100 }),
    __metadata("design:type", String)
], QrItem.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], QrItem.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_code', unique: true }),
    __metadata("design:type", String)
], QrItem.prototype, "qrCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_image_url', default: '' }),
    __metadata("design:type", String)
], QrItem.prototype, "qrImageUrl", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], QrItem.prototype, "createdAt", void 0);
exports.QrItem = QrItem = __decorate([
    (0, typeorm_1.Entity)('qr_items')
], QrItem);
//# sourceMappingURL=qr-item.entity.js.map