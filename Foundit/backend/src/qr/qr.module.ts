import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QrController } from './qr.controller';
import { QrService } from './qr.service';
import { QrItem } from '../common/entities/qr-item.entity';

@Module({
  imports: [TypeOrmModule.forFeature([QrItem])],
  controllers: [QrController],
  providers: [QrService],
  exports: [QrService],
})
export class QrModule {}
