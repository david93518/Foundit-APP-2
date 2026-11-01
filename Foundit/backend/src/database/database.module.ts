import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { SeedService } from './seed.service';
import { DatabaseSecurityService } from './database-security.service';

@Module({
  imports: [TypeOrmModule.forFeature([Item, User, UserPoints])],
  providers: [SeedService, DatabaseSecurityService],
})
export class DatabaseModule {}
