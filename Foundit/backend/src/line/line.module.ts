import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LineController } from './line.controller';
import { LineService } from './line.service';
import { LineBotService } from './line-bot.service';
import { LineLink } from '../common/entities/line-link.entity';
import { QrFinderNotice } from '../common/entities/qr-finder-notice.entity';
import { QrModule } from '../qr/qr.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CampusModule } from '../campus/campus.module';

@Module({
  imports: [TypeOrmModule.forFeature([LineLink, QrFinderNotice]), QrModule, NotificationsModule, CampusModule],
  controllers: [LineController],
  providers: [LineService, LineBotService],
})
export class LineModule {}
