import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QrController } from './qr.controller';
import { QrAdminController } from './qr-admin.controller';
import { QrLandingController } from './qr-landing.controller';
import { QrService } from './qr.service';
import { QrItem } from '../common/entities/qr-item.entity';
import { QrBatch } from '../common/entities/qr-batch.entity';

@Module({
  imports: [TypeOrmModule.forFeature([QrItem, QrBatch])],
  controllers: [QrController, QrAdminController],
  providers: [QrService, QrLandingController],
  exports: [QrService, QrLandingController],
})
export class QrModule {}
