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
exports.PointEvent = exports.PointEventType = void 0;
const typeorm_1 = require("typeorm");
const user_points_entity_1 = require("./user-points.entity");
var PointEventType;
(function (PointEventType) {
    PointEventType["FOUND_ITEM"] = "found_item";
    PointEventType["MATCH_SUCCESS"] = "match_success";
    PointEventType["DAILY_LOGIN"] = "daily_login";
    PointEventType["QR_SCAN"] = "qr_scan";
    PointEventType["REWARD_RECEIVED"] = "reward_received";
})(PointEventType || (exports.PointEventType = PointEventType = {}));
let PointEvent = class PointEvent {
    id;
    userPointsId;
    userPoints;
    type;
    points;
    description;
    createdAt;
};
exports.PointEvent = PointEvent;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], PointEvent.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_points_id' }),
    __metadata("design:type", String)
], PointEvent.prototype, "userPointsId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_points_entity_1.UserPoints, (up) => up.events),
    (0, typeorm_1.JoinColumn)({ name: 'user_points_id' }),
    __metadata("design:type", user_points_entity_1.UserPoints)
], PointEvent.prototype, "userPoints", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: PointEventType }),
    __metadata("design:type", String)
], PointEvent.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], PointEvent.prototype, "points", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], PointEvent.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], PointEvent.prototype, "createdAt", void 0);
exports.PointEvent = PointEvent = __decorate([
    (0, typeorm_1.Entity)('point_events')
], PointEvent);
//# sourceMappingURL=point-event.entity.js.map