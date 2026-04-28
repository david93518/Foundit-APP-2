import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Item, ItemType, ItemStatus } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';

/**
 * 僅在資料庫尚無任何物品時寫入示範資料（可刪除，不影響之後真實建立）。
 * 以環境變數 SEED_SAMPLE_DATA=false 可完全跳過。
 */
@Injectable()
export class SeedService implements OnModuleInit {
  private readonly log = new Logger(SeedService.name);

  constructor(
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(UserPoints) private readonly pointsRepo: Repository<UserPoints>,
  ) {}

  async onModuleInit(): Promise<void> {
    if (process.env.SEED_SAMPLE_DATA === 'false') {
      this.log.log('已設定 SEED_SAMPLE_DATA=false，略過示範資料');
      return;
    }

    try {
      const existing = await this.itemRepo.count();
      if (existing > 0) {
        this.log.log(`已有 ${existing} 筆物品，略過 seed`);
        return;
      }

      let demoUser = await this.userRepo.findOne({ where: { phone: '0900000000' } });
      if (!demoUser) {
        demoUser = await this.userRepo.save(
          this.userRepo.create({
            phone: '0900000000',
            name: '示範用戶',
            avatarUrl: '',
            isVerified: true,
          }),
        );
        await this.pointsRepo.save(
          this.pointsRepo.create({ userId: demoUser.id, points: 0 }),
        );
        this.log.log('已建立示範用戶 0900000000');
      }

      const now = Date.now();
      const samples: Partial<Item>[] = [
        {
          type: ItemType.LOST,
          userId: demoUser.id,
          title: '黑色真皮長夾（示範）',
          category: '錢包/皮夾',
          description: '此為資料庫 seed 示範，可刪除。',
          color: '黑色',
          images: [
            'https://images.unsplash.com/photo-1627123424-af7-4a07-a9df-fa71b9a898a8?w=400&q=80&auto=format',
          ],
          latitude: 25.0415,
          longitude: 121.5514,
          locationName: '台北市大安區（示範）',
          lostAt: new Date(now - 86400000 * 2),
          reward: 500,
          hasReward: true,
          storageLocation: '',
          handedToPolice: false,
          status: ItemStatus.ACTIVE,
        },
        {
          type: ItemType.FOUND,
          userId: demoUser.id,
          title: '拾得悠遊卡一張（示範）',
          category: '其他',
          description: '此為資料庫 seed 示範，可刪除。',
          color: '藍色',
          images: [
            'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&q=80&auto=format',
          ],
          latitude: 25.033,
          longitude: 121.5654,
          locationName: '台北車站（示範）',
          lostAt: new Date(now - 3600000 * 5),
          reward: 0,
          hasReward: false,
          storageLocation: '服務台',
          handedToPolice: false,
          status: ItemStatus.ACTIVE,
        },
      ];

      for (const row of samples) {
        await this.itemRepo.save(this.itemRepo.create(row as Item));
      }
      this.log.log(`已寫入 ${samples.length} 筆示範物品（可於 App 或 DB 刪除）`);
    } catch (e) {
      this.log.warn(`Seed 略過或失敗（資料庫未就緒時屬正常）: ${(e as Error).message}`);
    }
  }
}
