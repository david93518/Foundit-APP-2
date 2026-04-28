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
var ChatsGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatsGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const chats_service_1 = require("./chats.service");
const chat_mobile_serializer_1 = require("./chat-mobile.serializer");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_entity_1 = require("../common/entities/user.entity");
let ChatsGateway = ChatsGateway_1 = class ChatsGateway {
    chatsService;
    jwtService;
    userRepo;
    server;
    logger = new common_1.Logger(ChatsGateway_1.name);
    constructor(chatsService, jwtService, userRepo) {
        this.chatsService = chatsService;
        this.jwtService = jwtService;
        this.userRepo = userRepo;
    }
    async handleConnection(client) {
        try {
            const user = await this.extractUser(client);
            client.data.userId = user.id;
            client.data.user = user;
            this.logger.log(`用戶 ${user.name} 已連線 [${client.id}]`);
        }
        catch {
            this.logger.warn(`未授權的 WebSocket 連線 [${client.id}]`);
            client.disconnect();
        }
    }
    handleDisconnect(client) {
        this.logger.log(`Socket 斷線 [${client.id}]`);
    }
    async handleJoin(client, data) {
        await client.join(`chat:${data.chatId}`);
        return { event: 'joined', chatId: data.chatId };
    }
    async handleMessage(client, data) {
        const user = client.data.user;
        if (!user)
            throw new websockets_1.WsException('未登入');
        const msg = await this.chatsService.sendMessage(data.chatId, { content: data.content, type: data.type }, user);
        const payload = (0, chat_mobile_serializer_1.toMobileMessage)(msg);
        this.server.to(`chat:${data.chatId}`).emit('message', payload);
        return payload;
    }
    async handleRead(client, data) {
        await this.chatsService.markRead(data.chatId, client.data.userId);
        this.server.to(`chat:${data.chatId}`).emit('read', {
            chatId: data.chatId,
            userId: client.data.userId,
        });
    }
    pushToChat(chatId, event, payload) {
        this.server.to(`chat:${chatId}`).emit(event, payload);
    }
    async extractUser(client) {
        const token = client.handshake.auth?.token ||
            client.handshake.headers?.authorization;
        const cleaned = token?.replace('Bearer ', '') ?? '';
        const payload = this.jwtService.verify(cleaned);
        const user = await this.userRepo.findOne({ where: { id: payload.sub } });
        if (!user)
            throw new websockets_1.WsException('用戶不存在');
        return user;
    }
};
exports.ChatsGateway = ChatsGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], ChatsGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('join'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], ChatsGateway.prototype, "handleJoin", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('message'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], ChatsGateway.prototype, "handleMessage", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('read'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], ChatsGateway.prototype, "handleRead", null);
exports.ChatsGateway = ChatsGateway = ChatsGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/chat', cors: { origin: '*' } }),
    __param(2, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [chats_service_1.ChatsService,
        jwt_1.JwtService,
        typeorm_2.Repository])
], ChatsGateway);
//# sourceMappingURL=chats.gateway.js.map