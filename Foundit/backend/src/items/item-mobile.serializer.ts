import { Item } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';

type ItemWithUser = Item & { user?: User | null };

/** 轉成 Android App（Gson snake_case + 毫秒時間戳）期望的 JSON 形狀 */
export function toMobileItem(item: ItemWithUser): Record<string, unknown> {
  const u = item.user;
  return {
    id: item.id,
    type: item.type,
    user_id: item.userId,
    user_name: u?.name ?? '',
    user_avatar: u?.avatarUrl ?? '',
    user_verified: u?.isVerified ?? false,
    title: item.title,
    category: item.category,
    description: item.description ?? '',
    color: item.color ?? '',
    images: item.images ?? [],
    latitude: item.latitude != null ? Number(item.latitude) : 0,
    longitude: item.longitude != null ? Number(item.longitude) : 0,
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
