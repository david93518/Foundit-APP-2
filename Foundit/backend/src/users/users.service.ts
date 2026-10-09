import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { verifyGoogleIdToken } from '../auth/google-id-token';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { ItemsService } from '../items/items.service';
import { Item, ItemStatus, ItemType } from '../common/entities/item.entity';
import { Message } from '../common/entities/message.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { OtpService } from '../auth/otp.service';
import { ChatsGateway } from '../chats/chats.gateway';
import { verifyInvitedCredentials } from '../auth/invited-credentials';
import { isGoogleAvatar, isOwnUpload, publicBaseUrl, uploadSecret } from '../common/media-url';
import { findSensitiveData, isReservedName } from '../common/text-safety';
import { UploadCleanup } from '../common/entities/upload-cleanup.entity';
import { Notification } from '../common/entities/notification.entity';
import { MessageType } from '../common/entities/message.entity';
import { SAFE_IMAGE_NAME } from '../upload/private-media';

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
    private readonly otpService: OtpService,
    @InjectRepository(Item) private readonly itemRepo: Repository<Item>,
    @InjectRepository(Message) private readonly messageRepo: Repository<Message>,
    @InjectRepository(QrItem) private readonly qrRepo: Repository<QrItem>,
    private readonly gateway: ChatsGateway,
    private readonly config: ConfigService,
  ) {}

  async getMe(userId: string): Promise<User> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用戶不存在');
    return user;
  }

  async updateProfile(userId: string, payload: UpdateProfilePayload): Promise<User> {
    const user = await this.getMe(userId);
    if (payload.name !== undefined && payload.name.length > 0 && payload.name !== user.name) {
      // 暱稱會出現在刊登、聊天與防丟牌掃描頁，不能冒充官方，也不能拿來公開聯絡方式。
      if (user.role !== 'admin' && isReservedName(payload.name)) {
        throw new BadRequestException('這個名稱保留給 FOUND !T 官方使用，請換一個');
      }
      const sensitive = findSensitiveData(payload.name);
      if (sensitive) throw new BadRequestException(`暱稱不能包含${sensitive}`);
      user.name = payload.name;
    }
    if (payload.avatarUrl !== undefined) {
      const avatar = payload.avatarUrl.trim();
      const allowed = avatar === '' || avatar === user.avatarUrl || isGoogleAvatar(avatar) ||
        isOwnUpload(avatar, user.id, publicBaseUrl(this.config), uploadSecret(this.config));
      if (!allowed) throw new BadRequestException('頭像必須是上傳到 FOUND !T 的圖片');
      user.avatarUrl = avatar;
    }
    if (payload.bio !== undefined) user.bio = payload.bio;
    if (payload.email !== undefined && payload.email !== user.email) {
      // Google 帳號的 email 每次登入都由 Google 驗證後覆寫，不接受自行修改。
      if (user.googleSub) throw new BadRequestException('Google 帳號的 email 由 Google 管理');
      user.email = payload.email;
    }
    return this.userRepo.save(user);
  }

  async deleteAccount(userId: string, otp: string): Promise<void> {
    const user = await this.getMe(userId);
    if (user.status !== 'active') throw new BadRequestException('帳號無法刪除');
    if (!this.otpService.verify(user.phone, otp)) {
      throw new BadRequestException('驗證碼錯誤或已過期');
    }
    await this.eraseAccount(user);
  }

  async deleteGoogleAccount(userId: string, idToken: string): Promise<void> {
    const user = await this.getMe(userId);
    const audience = this.config.get<string>('GOOGLE_WEB_CLIENT_ID')?.trim();
    if (!audience || !user.googleSub || user.status !== 'active') {
      throw new BadRequestException('請使用原本的 Google 帳號確認');
    }
    try {
      const identity = await verifyGoogleIdToken(idToken, audience);
      const age = Math.floor(Date.now() / 1000) - identity.issuedAt;
      if (identity.sub !== user.googleSub || !Number.isFinite(age) || age < -60 || age > 300) {
        throw new Error('Reauthentication must be recent and match the account');
      }
    } catch {
      throw new UnauthorizedException('請重新選擇原本的 Google 帳號，帳號尚未刪除');
    }
    await this.eraseAccount(user);
  }

  private async eraseAccount(user: User): Promise<void> {
    const userId = user.id;
    const now = new Date();
    await this.userRepo.manager.transaction(async manager => {
      const current = await manager.findOne(User, {
        where: { id: userId }, lock: { mode: 'pessimistic_write' },
      });
      if (!current || current.status !== 'active') throw new UnauthorizedException('帳號無法刪除');
      const items = await manager.find(Item, { where: { userId }, select: ['images'] });
      const images = await manager.find(Message, { where: { senderId: userId, type: MessageType.IMAGE }, select: ['content'] });
      const urls = [...items.flatMap(item => item.images ?? []), ...images.map(image => image.content), current.avatarUrl];
      const base = publicBaseUrl(this.config);
      const files = urls.flatMap(value => {
        try {
          const url = new URL(value);
          const name = url.pathname.split('/').pop() ?? '';
          return base && url.origin === new URL(base).origin && SAFE_IMAGE_NAME.test(name) ? [name] : [];
        } catch { return []; }
      });
      // The retry job and all PII changes commit or roll back together.
      await manager.upsert(UploadCleanup, { userId, files: [...new Set(files)] }, ['userId']);
      await manager.getRepository(Item)
      .createQueryBuilder()
      .update(Item)
      .set({
        status: ItemStatus.CLOSED,
        hiddenAt: now,
        title: '已移除的刊登',
        description: '',
        images: [],
        locationName: '',
        latitude: null,
        longitude: null,
        storageLocation: '',
      })
      .where('user_id = :userId', { userId })
      .execute();
      await manager.getRepository(Message)
      .createQueryBuilder()
      .update(Message)
      .set({ content: '（訊息已刪除）' })
      .where('sender_id = :userId', { userId })
      .execute();
      await manager.update(QrItem, { userId }, { revokedAt: now, name: '已移除的物品', description: '', qrImageUrl: '' });
      await manager.update(Notification, { userId }, { title: '', content: '' });
      await manager.update(User, { id: userId }, {
        status: 'deleted', tokenVersion: () => '"token_version" + 1',
        phone: `deleted:${userId}`.slice(0, 100), name: '已刪除的使用者',
        email: '', bio: '', avatarUrl: '', googleSub: null, fcmToken: null, isVerified: false,
      });
    });
    this.gateway.disconnectUser(userId);
  }

  async deleteInvitedAccount(userId: string, username: string, password: string): Promise<void> {
    const verified = await verifyInvitedCredentials(this.config, username, password);
    if (verified !== userId) throw new UnauthorizedException('帳號或密碼不正確');
    const user = await this.getMe(userId);
    if (user.status !== 'active' || user.role !== 'user' || user.googleSub ||
        user.phone !== `invited:${username}`) throw new UnauthorizedException('帳號無法刪除');
    await this.eraseAccount(user);
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
