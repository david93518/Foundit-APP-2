import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LineController } from './line.controller';
import { LineService } from './line.service';
import { BotSecretGuard } from './bot-secret.guard';
import { LineLink } from '../common/entities/line-link.entity';
import { QrFinderNotice } from '../common/entities/qr-finder-notice.entity';
import { QrModule } from '../qr/qr.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TypeOrmModule.forFeature([LineLink, QrFinderNotice]), QrModule, NotificationsModule],
  controllers: [LineController],
  providers: [LineService, BotSecretGuard],
})
export class LineModule {}
