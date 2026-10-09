import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';

type ItemWithUser = Item & { user?: User | null };

/**
 * 轉成 App（snake_case + 毫秒時間戳）期望的 JSON 形狀。
 * 刊登者的帳號 id 只回給刊登者本人（App 用它判斷「這是我的刊登」）；
 * 其他人拿到空字串，無法用 id 串起同一個人的所有刊登。viewerId 必填，每個呼叫點都要明確決定。
 */
export function toMobileItem(item: ItemWithUser, viewerId: string | null): Record<string, unknown> {
  const u = item.user;
  const owner = viewerId != null && viewerId === item.userId;
  // 其他人只拿到約 100 公尺精度的位置：地圖與導航夠用，又不會精準到門牌（例如住家）。
  const coordinate = (value: number | null) => {
    if (value == null) return null;
    return owner ? Number(value) : Math.round(Number(value) * 1000) / 1000;
  };
  return {
    id: item.id,
    type: item.type,
    user_id: owner ? item.userId : '',
    user_name: u?.name ?? '',
    user_avatar: u?.avatarUrl ?? '',
    user_verified: u?.isVerified ?? false,
    title: item.title,
    category: item.category,
    description: item.description ?? '',
    color: item.color ?? '',
    images: item.images ?? [],
    latitude: coordinate(item.latitude),
    longitude: coordinate(item.longitude),
    location_name: item.locationName ?? '',
    lost_at: item.lostAt ? new Date(item.lostAt).getTime() : Date.now(),
    reward: item.reward ?? 0,
    has_reward: item.hasReward ?? false,
    storage_location: item.storageLocation ?? '',
    handed_to_police: item.handedToPolice ?? false,
    status: item.status,
    created_at: item.createdAt ? new Date(item.createdAt).getTime() : Date.now(),
    updated_at: item.updatedAt ? new Date(item.updatedAt).getTime() : Date.now(),
  };
}
