import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';
import { Message } from '../common/entities/message.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { ItemsModule } from '../items/items.module';
import { AuthModule } from '../auth/auth.module';
import { ChatsModule } from '../chats/chats.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Item, Message, QrItem]),
    ItemsModule,
    AuthModule,
    ChatsModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
