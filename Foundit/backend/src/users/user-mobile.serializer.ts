import { User } from '../common/entities/user.entity';

/**
 * 將 User 實體轉換成行動端期待的 JSON 形狀。
 *
 * 重要：絕對不要在這裡輸出 fcmToken / googleSub / lineSub 等敏感欄位，
 * 這些只供伺服器內部使用。
 */
export function toMobileUser(u: User): Record<string, unknown> {
  return {
    id: u.id,
    name: u.name ?? '',
    phone: u.phone ?? '',
    email: u.email ?? '',
    bio: u.bio ?? '',
    avatar_url: u.avatarUrl ?? '',
    is_verified: u.isVerified ?? false,
    points: typeof (u as { points?: number }).points === 'number'
      ? (u as { points?: number }).points
      : 0,
    created_at: u.createdAt ? new Date(u.createdAt).getTime() : Date.now(),
  };
}
