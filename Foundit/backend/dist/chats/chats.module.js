"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const jwt_1 = require("@nestjs/jwt");
const config_1 = require("@nestjs/config");
const chats_controller_1 = require("./chats.controller");
const chats_service_1 = require("./chats.service");
const chats_gateway_1 = require("./chats.gateway");
const chat_entity_1 = require("../common/entities/chat.entity");
const message_entity_1 = require("../common/entities/message.entity");
const item_entity_1 = require("../common/entities/item.entity");
const user_entity_1 = require("../common/entities/user.entity");
let ChatsModule = class ChatsModule {
};
exports.ChatsModule = ChatsModule;
exports.ChatsModule = ChatsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([chat_entity_1.Chat, message_entity_1.Message, item_entity_1.Item, user_entity_1.User]),
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    secret: config.get('JWT_SECRET') ?? 'fallback-secret',
                }),
                inject: [config_1.ConfigService],
            }),
        ],
        controllers: [chats_controller_1.ChatsController],
        providers: [chats_service_1.ChatsService, chats_gateway_1.ChatsGateway],
        exports: [chats_service_1.ChatsService, chats_gateway_1.ChatsGateway],
    })
], ChatsModule);
//# sourceMappingURL=chats.module.js.map