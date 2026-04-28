import { Notification } from '../common/entities/notification.entity';

/**
 * 將 Notification 實體轉成行動端期待的 JSON 形狀。
 * - 時間統一輸出毫秒 timestamp
 * - 不外洩 user 欄位（只給 user_id）
 */
export function toMobileNotification(n: Notification): Record<string, unknown> {
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
