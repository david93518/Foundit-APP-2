"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const auth_module_1 = require("./auth/auth.module");
const users_module_1 = require("./users/users.module");
const items_module_1 = require("./items/items.module");
const chats_module_1 = require("./chats/chats.module");
const notifications_module_1 = require("./notifications/notifications.module");
const qr_module_1 = require("./qr/qr.module");
const points_module_1 = require("./points/points.module");
const ai_module_1 = require("./ai/ai.module");
const upload_module_1 = require("./upload/upload.module");
const user_entity_1 = require("./common/entities/user.entity");
const item_entity_1 = require("./common/entities/item.entity");
const chat_entity_1 = require("./common/entities/chat.entity");
const message_entity_1 = require("./common/entities/message.entity");
const notification_entity_1 = require("./common/entities/notification.entity");
const qr_item_entity_1 = require("./common/entities/qr-item.entity");
const user_points_entity_1 = require("./common/entities/user-points.entity");
const point_event_entity_1 = require("./common/entities/point-event.entity");
const database_module_1 = require("./database/database.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            database_module_1.DatabaseModule,
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    type: 'postgres',
                    host: config.get('DB_HOST', 'localhost'),
                    port: config.get('DB_PORT', 5432),
                    database: config.get('DB_NAME', 'foundit'),
                    username: config.get('DB_USER', 'foundit_user'),
                    password: config.get('DB_PASS', 'foundit_pass'),
                    entities: [user_entity_1.User, item_entity_1.Item, chat_entity_1.Chat, message_entity_1.Message, notification_entity_1.Notification, qr_item_entity_1.QrItem, user_points_entity_1.UserPoints, point_event_entity_1.PointEvent],
                    synchronize: config.get('NODE_ENV') !== 'production',
                    logging: config.get('NODE_ENV') === 'development',
                }),
                inject: [config_1.ConfigService],
            }),
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            items_module_1.ItemsModule,
            chats_module_1.ChatsModule,
            notifications_module_1.NotificationsModule,
            qr_module_1.QrModule,
            points_module_1.PointsModule,
            ai_module_1.AiModule,
            upload_module_1.UploadModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map