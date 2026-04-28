"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toMobileMessage = toMobileMessage;
exports.toMobileChat = toMobileChat;
function toMobileMessage(msg) {
    const s = msg.sender;
    return {
        id: msg.id,
        chat_id: msg.chatId,
        sender_id: msg.senderId,
        sender_name: s?.name ?? '',
        sender_avatar: s?.avatarUrl ?? '',
        content: msg.content ?? '',
        type: msg.type,
        read_at: msg.readAt ? new Date(msg.readAt).getTime() : null,
        created_at: msg.createdAt ? new Date(msg.createdAt).getTime() : Date.now(),
    };
}
function toMobileChat(chat, currentUserId) {
    const participants = chat.participants ?? [];
    const other = participants.find((p) => p.id !== currentUserId);
    const item = chat.item;
    const last = chat.lastMessage ?? (chat.messages && chat.messages[0]) ?? null;
    const imgs = item?.images ?? [];
    const firstImage = Array.isArray(imgs) && imgs.length > 0 ? imgs[0] : '';
    return {
        id: chat.id,
        item_id: chat.itemId,
        item_title: item?.title ?? '',
        item_image: firstImage,
        participants: participants.map((p) => ({
            id: p.id,
            name: p.name ?? '',
            phone: p.phone ?? '',
            avatar_url: p.avatarUrl ?? '',
        })),
        other_user_name: other?.name ?? '',
        other_user_avatar: other?.avatarUrl ?? '',
        last_message: last?.content ?? '',
        last_message_at: last?.createdAt
            ? new Date(last.createdAt).getTime()
            : new Date(chat.updatedAt ?? chat.createdAt ?? Date.now()).getTime(),
        unread_count: chat.unreadCount ?? 0,
    };
}
//# sourceMappingURL=chat-mobile.serializer.js.map