import { OnModuleInit } from '@nestjs/common';
import { Repository } from 'typeorm';
import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
export declare class SeedService implements OnModuleInit {
    private readonly itemRepo;
    private readonly userRepo;
    private readonly pointsRepo;
    private readonly log;
    constructor(itemRepo: Repository<Item>, userRepo: Repository<User>, pointsRepo: Repository<UserPoints>);
    onModuleInit(): Promise<void>;
}
