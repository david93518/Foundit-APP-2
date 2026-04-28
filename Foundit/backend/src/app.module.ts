import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ItemsModule } from './items/items.module';
import { ChatsModule } from './chats/chats.module';
import { NotificationsModule } from './notifications/notifications.module';
import { QrModule } from './qr/qr.module';
import { PointsModule } from './points/points.module';
import { AiModule } from './ai/ai.module';
import { UploadModule } from './upload/upload.module';
import { User } from './common/entities/user.entity';
import { Item } from './common/entities/item.entity';
import { Chat } from './common/entities/chat.entity';
import { Message } from './common/entities/message.entity';
import { Notification } from './common/entities/notification.entity';
import { QrItem } from './common/entities/qr-item.entity';
import { UserPoints } from './common/entities/user-points.entity';
import { PointEvent } from './common/entities/point-event.entity';
import { DatabaseModule } from './database/database.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: config.get<number>('DB_PORT', 5432),
        database: config.get<string>('DB_NAME', 'foundit'),
        username: config.get<string>('DB_USER', 'foundit_user'),
        password: config.get<string>('DB_PASS', 'foundit_pass'),
        entities: [User, Item, Chat, Message, Notification, QrItem, UserPoints, PointEvent],
        synchronize: config.get<string>('NODE_ENV') !== 'production',
        logging: config.get<string>('NODE_ENV') === 'development',
      }),
      inject: [ConfigService],
    }),
    AuthModule,
    UsersModule,
    ItemsModule,
    ChatsModule,
    NotificationsModule,
    QrModule,
    PointsModule,
    AiModule,
    UploadModule,
  ],
})
export class AppModule {}
