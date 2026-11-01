import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QrController } from './qr.controller';
import { QrAdminController } from './qr-admin.controller';
import { QrLandingController } from './qr-landing.controller';
import { QrService } from './qr.service';
import { QrItem } from '../common/entities/qr-item.entity';
import { User } from '../common/entities/user.entity';
import { QrBatch } from '../common/entities/qr-batch.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { QrScanNotifier } from './qr-scan-notifier.service';

@Module({
  imports: [TypeOrmModule.forFeature([QrItem, QrBatch, User]), NotificationsModule],
  controllers: [QrController, QrAdminController],
  providers: [QrService, QrLandingController, QrScanNotifier],
  exports: [QrService, QrLandingController],
})
export class QrModule {}
