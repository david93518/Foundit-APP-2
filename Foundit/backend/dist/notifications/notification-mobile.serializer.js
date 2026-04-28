"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toMobileNotification = toMobileNotification;
function toMobileNotification(n) {
    return {
        id: n.id,
        user_id: n.userId,
        type: n.type,
        title: n.title,
        content: n.content,
        item_id: n.itemId ?? '',
        chat_id: n.chatId ?? '',
        is_read: n.isRead,
        created_at: n.createdAt ? new Date(n.createdAt).getTime() : Date.now(),
    };
}
//# sourceMappingURL=notification-mobile.serializer.js.map