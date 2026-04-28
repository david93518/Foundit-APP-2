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
exports.ChatsController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const chats_service_1 = require("./chats.service");
const chats_gateway_1 = require("./chats.gateway");
const create_chat_dto_1 = require("./dto/create-chat.dto");
const send_message_dto_1 = require("./dto/send-message.dto");
const chat_mobile_serializer_1 = require("./chat-mobile.serializer");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../common/decorators/current-user.decorator");
const user_entity_1 = require("../common/entities/user.entity");
let ChatsController = class ChatsController {
    chatsService;
    chatsGateway;
    constructor(chatsService, chatsGateway) {
        this.chatsService = chatsService;
        this.chatsGateway = chatsGateway;
    }
    async create(dto, user) {
        const chat = await this.chatsService.createOrGet(dto, user);
        return { success: true, data: (0, chat_mobile_serializer_1.toMobileChat)(chat, user.id) };
    }
    async findAll(user) {
        const rows = await this.chatsService.findAllForUser(user.id);
        return { success: true, data: rows.map((c) => (0, chat_mobile_serializer_1.toMobileChat)(c, user.id)) };
    }
    async unreadCount(user) {
        const count = await this.chatsService.unreadTotalForUser(user.id);
        return { success: true, data: { count } };
    }
    async getMessages(id, user, page, pageSize) {
        const rows = await this.chatsService.getMessages(id, user.id, page, pageSize);
        return { success: true, data: rows.map(chat_mobile_serializer_1.toMobileMessage) };
    }
    async sendMessage(id, dto, user) {
        const msg = await this.chatsService.sendMessage(id, dto, user);
        const payload = (0, chat_mobile_serializer_1.toMobileMessage)(msg);
        this.chatsGateway.pushToChat(id, 'message', payload);
        return { success: true, data: payload };
    }
    async markRead(id, user) {
        await this.chatsService.markRead(id, user.id);
        this.chatsGateway.pushToChat(id, 'read', { chatId: id, userId: user.id });
        return { success: true };
    }
};
exports.ChatsController = ChatsController;
__decorate([
    (0, common_1.Post)(),
    (0, swagger_1.ApiOperation)({ summary: '建立或取得聊天室' }),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_chat_dto_1.CreateChatDto, user_entity_1.User]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({ summary: '取得我的聊天列表（含未讀數與最後訊息）' }),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [user_entity_1.User]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('unread-count'),
    (0, swagger_1.ApiOperation)({ summary: '取得我的所有對話未讀總數（給 nav badge 用）' }),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [user_entity_1.User]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "unreadCount", null);
__decorate([
    (0, common_1.Get)(':id/messages'),
    (0, swagger_1.ApiOperation)({ summary: '取得聊天室訊息' }),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __param(2, (0, common_1.Query)('page', new common_1.DefaultValuePipe(1), common_1.ParseIntPipe)),
    __param(3, (0, common_1.Query)('page_size', new common_1.DefaultValuePipe(50), common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, user_entity_1.User, Number, Number]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "getMessages", null);
__decorate([
    (0, common_1.Post)(':id/messages'),
    (0, swagger_1.ApiOperation)({ summary: '發送訊息（REST，推薦用 WebSocket）' }),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, send_message_dto_1.SendMessageDto,
        user_entity_1.User]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "sendMessage", null);
__decorate([
    (0, common_1.Patch)(':id/read'),
    (0, swagger_1.ApiOperation)({ summary: '將聊天室所有對方訊息標記為已讀' }),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, user_entity_1.User]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "markRead", null);
exports.ChatsController = ChatsController = __decorate([
    (0, swagger_1.ApiTags)('聊天'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('chats'),
    __metadata("design:paramtypes", [chats_service_1.ChatsService,
        chats_gateway_1.ChatsGateway])
], ChatsController);
//# sourceMappingURL=chats.controller.js.map