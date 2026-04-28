import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { ItemsService } from '../items/items.service';
import { ItemType } from '../common/entities/item.entity';

export interface UserStats {
  /** 我發布過的物品總數 */
  posted: number;
  /** 成功幫助 = RESOLVED 物品數 */
  helpful: number;
  /** 收藏（待 bookmarks 表，先以 0 表達） */
  bookmarks: number;
  /** 拆給徽章計算用 */
  found_count: number;
  lost_count: number;
}

export interface BadgeInfo {
  code: string;
  name: string;
  emoji: string;
  unlocked: boolean;
  /** 解鎖進度（達成 = 1.0） */
  progress: number;
  description: string;
}

export interface UpdateProfilePayload {
  name?: string;
  avatarUrl?: string;
  bio?: string;
  email?: string;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    private readonly itemsService: ItemsService,
  ) {}

  async getMe(userId: string): Promise<User> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用戶不存在');
    return user;
  }

  async updateProfile(userId: string, payload: UpdateProfilePayload): Promise<User> {
    const user = await this.getMe(userId);
    if (payload.name !== undefined && payload.name.length > 0) {
      user.name = payload.name;
    }
    if (payload.avatarUrl !== undefined) user.avatarUrl = payload.avatarUrl;
    if (payload.bio !== undefined) user.bio = payload.bio;
    if (payload.email !== undefined) user.email = payload.email;
    return this.userRepo.save(user);
  }

  async getMyItems(userId: string) {
    return this.itemsService.findByUser(userId);
  }

  async getStats(userId: string): Promise<UserStats> {
    const [posted, helpful, foundCount, lostCount] = await Promise.all([
      this.itemsService.countByUser(userId),
      this.itemsService.countResolvedByUser(userId),
      this.itemsService.countByUserAndType(userId, ItemType.FOUND),
      this.itemsService.countByUserAndType(userId, ItemType.LOST),
    ]);

    return {
      posted,
      helpful,
      bookmarks: 0,
      found_count: foundCount,
      lost_count: lostCount,
    };
  }

  /** 依即時統計計算徽章解鎖狀態 */
  async getBadges(userId: string): Promise<BadgeInfo[]> {
    const stats = await this.getStats(userId);
    const user = await this.getMe(userId);
    const accountDays = Math.floor(
      (Date.now() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24),
    );

    const list: BadgeInfo[] = [
      this.badge(
        'helpful_citizen',
        '熱心公民',
        '🎖️',
        '完成第一次成功幫助',
        stats.helpful >= 1,
        Math.min(stats.helpful / 1, 1),
      ),
      this.badge(
        'picker_10',
        '撿到 10 件',
        '🏆',
        '張貼 10 件以上「拾獲」物品',
        stats.found_count >= 10,
        Math.min(stats.found_count / 10, 1),
      ),
      this.badge(
        'treasure_hunter',
        '尋寶達人',
        '🔍',
        '張貼 5 件以上「遺失」物品',
        stats.lost_count >= 5,
        Math.min(stats.lost_count / 5, 1),
      ),
      this.badge(
        'kind_soul',
        '善心人士',
        '💚',
        '成功幫助 5 次以上',
        stats.helpful >= 5,
        Math.min(stats.helpful / 5, 1),
      ),
      this.badge(
        'streak_30',
        '連續 30 天',
        '🔥',
        '帳號使用滿 30 天',
        accountDays >= 30,
        Math.min(accountDays / 30, 1),
      ),
    ];

    return list;
  }

  private badge(
    code: string,
    name: string,
    emoji: string,
    description: string,
    unlocked: boolean,
    progress: number,
  ): BadgeInfo {
    return { code, name, emoji, unlocked, progress, description };
  }
}
