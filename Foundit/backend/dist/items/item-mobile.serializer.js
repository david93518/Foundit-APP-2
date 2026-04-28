"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toMobileItem = toMobileItem;
function toMobileItem(item) {
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
//# sourceMappingURL=item-mobile.serializer.js.map