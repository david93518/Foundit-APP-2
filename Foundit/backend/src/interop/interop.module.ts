import { ModerationModule } from '../moderation/moderation.module';
import { Module } from '@nestjs/common';
import { InteropController } from './interop.controller';
import { ItemsModule } from '../items/items.module';
import { PointsModule } from '../points/points.module';

@Module({
  imports: [ItemsModule, PointsModule, ModerationModule],
  controllers: [InteropController],
})
export class InteropModule {}
