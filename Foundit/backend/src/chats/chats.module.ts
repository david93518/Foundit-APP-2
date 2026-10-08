import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { Block } from '../common/entities/block.entity';
import { readJwtSecret } from '../auth/jwt-secret';

@Module({
  imports: [
    TypeOrmModule.forFeature([Chat, Message, Item, User, Block]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: readJwtSecret(config),
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [ChatsController],
  providers: [ChatsService, ChatsGateway],
  exports: [ChatsService, ChatsGateway],
})
export class ChatsModule {}
