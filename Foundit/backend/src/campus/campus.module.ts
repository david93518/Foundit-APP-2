import { Module } from '@nestjs/common';
import { CampusController } from './campus.controller';
import { CampusService } from './campus.service';
import { UploadModule } from '../upload/upload.module';
@Module({
  imports: [UploadModule],
  controllers: [CampusController],
  providers: [CampusService],
})
export class CampusModule {}
