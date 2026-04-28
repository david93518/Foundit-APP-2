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
exports.Item = exports.ItemStatus = exports.ItemType = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("./user.entity");
const chat_entity_1 = require("./chat.entity");
var ItemType;
(function (ItemType) {
    ItemType["LOST"] = "LOST";
    ItemType["FOUND"] = "FOUND";
})(ItemType || (exports.ItemType = ItemType = {}));
var ItemStatus;
(function (ItemStatus) {
    ItemStatus["ACTIVE"] = "ACTIVE";
    ItemStatus["RESOLVED"] = "RESOLVED";
    ItemStatus["CLOSED"] = "CLOSED";
})(ItemStatus || (exports.ItemStatus = ItemStatus = {}));
let Item = class Item {
    id;
    type;
    userId;
    user;
    title;
    category;
    description;
    color;
    images;
    latitude;
    longitude;
    locationName;
    lostAt;
    reward;
    hasReward;
    storageLocation;
    handedToPolice;
    status;
    createdAt;
    updatedAt;
    chats;
};
exports.Item = Item;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Item.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ItemType }),
    __metadata("design:type", String)
], Item.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", String)
], Item.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, (user) => user.items, { eager: false }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], Item.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100 }),
    __metadata("design:type", String)
], Item.prototype, "title", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 50 }),
    __metadata("design:type", String)
], Item.prototype, "category", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], Item.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 30, default: '' }),
    __metadata("design:type", String)
], Item.prototype, "color", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', array: true, default: [] }),
    __metadata("design:type", Array)
], Item.prototype, "images", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 10, scale: 7, nullable: true }),
    __metadata("design:type", Number)
], Item.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 10, scale: 7, nullable: true }),
    __metadata("design:type", Number)
], Item.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'location_name', default: '' }),
    __metadata("design:type", String)
], Item.prototype, "locationName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'lost_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Date)
], Item.prototype, "lostAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], Item.prototype, "reward", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'has_reward', default: false }),
    __metadata("design:type", Boolean)
], Item.prototype, "hasReward", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'storage_location', default: '' }),
    __metadata("design:type", String)
], Item.prototype, "storageLocation", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'handed_to_police', default: false }),
    __metadata("design:type", Boolean)
], Item.prototype, "handedToPolice", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ItemStatus, default: ItemStatus.ACTIVE }),
    __metadata("design:type", String)
], Item.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Item.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Item.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => chat_entity_1.Chat, (chat) => chat.item),
    __metadata("design:type", Array)
], Item.prototype, "chats", void 0);
exports.Item = Item = __decorate([
    (0, typeorm_1.Entity)('items'),
    (0, typeorm_1.Index)('idx_items_status_created', ['status', 'createdAt']),
    (0, typeorm_1.Index)('idx_items_user', ['userId']),
    (0, typeorm_1.Index)('idx_items_type_status', ['type', 'status']),
    (0, typeorm_1.Index)('idx_items_category', ['category'])
], Item);
//# sourceMappingURL=item.entity.js.map