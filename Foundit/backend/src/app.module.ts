import { Module } from '@nestjs/common';
import { LocationsModule } from './locations/locations.module';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ItemsModule } from './items/items.module';
import { ChatsModule } from './chats/chats.module';
import { NotificationsModule } from './notifications/notifications.module';
import { QrModule } from './qr/qr.module';
import { PushModule } from './push/push.module';
import { PointsModule } from './points/points.module';
import { AiModule } from './ai/ai.module';
import { UploadModule } from './upload/upload.module';
import { ModerationModule } from './moderation/moderation.module';
import { HealthController } from './health.controller';
import { AbuseLimitInterceptor } from './common/abuse-limit.interceptor';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { User } from './common/entities/user.entity';
import { Item } from './common/entities/item.entity';
import { Chat } from './common/entities/chat.entity';
import { Message } from './common/entities/message.entity';
import { Notification } from './common/entities/notification.entity';
import { QrItem } from './common/entities/qr-item.entity';
import { UserPoints } from './common/entities/user-points.entity';
import { PointEvent } from './common/entities/point-event.entity';
import { Report } from './common/entities/report.entity';
import { Block } from './common/entities/block.entity';
import { AdminAction } from './common/entities/admin-action.entity';
import { DatabaseModule } from './database/database.module';
import { ChatRateLimit } from './common/entities/chat-rate-limit.entity';
import { UploadCleanup } from './common/entities/upload-cleanup.entity';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => {
        const production = config.get<string>('NODE_ENV') === 'production';
        const password = config.get<string>('DB_PASS') ?? (production ? '' : 'foundit_pass');
        if (production && (!password || password === 'foundit_pass' || password.startsWith('change-me'))) {
          throw new Error('正式環境的 DB_PASS 缺失或仍是範例值，拒絕啟動');
        }
        return {
          type: 'postgres' as const,
          host: config.get<string>('DB_HOST', 'localhost'),
          port: config.get<number>('DB_PORT', 5432),
          database: config.get<string>('DB_NAME', 'foundit'),
          username: config.get<string>('DB_USER', 'foundit_user'),
          password,
          entities: [User, Item, Chat, Message, Notification, QrItem, UserPoints, PointEvent, Report, Block, AdminAction, ChatRateLimit, UploadCleanup],
          synchronize: !production,
          // 正式環境的執行帳號只有資料讀寫權限；擴充套件與 schema 由 migration 帳號負責。
          installExtensions: !production,
          logging: config.get<string>('NODE_ENV') === 'development',
        };
      },
      inject: [ConfigService],
    }),
    AuthModule,
    LocationsModule,
    UsersModule,
    ItemsModule,
    ChatsModule,
    NotificationsModule,
    QrModule,
    PushModule,
    PointsModule,
    AiModule,
    UploadModule,
    ModerationModule,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_INTERCEPTOR, useClass: AbuseLimitInterceptor }],
})
export class AppModule {}
