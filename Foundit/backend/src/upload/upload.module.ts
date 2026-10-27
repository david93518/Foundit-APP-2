import { Module } from '@nestjs/common';
import { UploadController } from './upload.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Message } from '../common/entities/message.entity';
import { UploadCleanup } from '../common/entities/upload-cleanup.entity';
import { UploadCleanupService } from './upload-cleanup.service';
import { MediaStorageService } from './media-storage.service';

@Module({
  imports: [TypeOrmModule.forFeature([Message, UploadCleanup])],
  controllers: [UploadController],
  providers: [UploadCleanupService, MediaStorageService],
  exports: [MediaStorageService],
})
export class UploadModule {}
