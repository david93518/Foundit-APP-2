import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PointsController } from './points.controller';
import { PointsService } from './points.service';
import { UserPoints } from '../common/entities/user-points.entity';
import { PointEvent } from '../common/entities/point-event.entity';

@Module({
  imports: [TypeOrmModule.forFeature([UserPoints, PointEvent])],
  controllers: [PointsController],
  providers: [PointsService],
  exports: [PointsService],
})
export class PointsModule {}
