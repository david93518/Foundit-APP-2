import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ModerationController } from './moderation.controller';
import { AdminController } from './admin.controller';
import { ModerationService } from './moderation.service';
import { Report } from '../common/entities/report.entity';
import { Block } from '../common/entities/block.entity';
import { AdminAction } from '../common/entities/admin-action.entity';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';
import { ChatsModule } from '../chats/chats.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Report, Block, AdminAction, User, Item]),
    ChatsModule,
  ],
  controllers: [ModerationController, AdminController],
  providers: [ModerationService],
  exports: [ModerationService],
})
export class ModerationModule {}
