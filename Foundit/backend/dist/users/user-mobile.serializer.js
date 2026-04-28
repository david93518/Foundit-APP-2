"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toMobileUser = toMobileUser;
function toMobileUser(u) {
    return {
        id: u.id,
        name: u.name ?? '',
        phone: u.phone ?? '',
        email: u.email ?? '',
        bio: u.bio ?? '',
        avatar_url: u.avatarUrl ?? '',
        is_verified: u.isVerified ?? false,
        points: typeof u.points === 'number'
            ? u.points
            : 0,
        created_at: u.createdAt ? new Date(u.createdAt).getTime() : Date.now(),
    };
}
//# sourceMappingURL=user-mobile.serializer.js.map