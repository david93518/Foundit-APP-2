import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';

type ChatWithRels = Chat & {
  item?: Item | null;
  participants?: User[];
  messages?: Message[];
  /** 由 service 層計算後夾帶 */
  unreadCount?: number;
  lastMessage?: Message | null;
};

type MessageWithSender = Message & { sender?: User | null };

/** 與 Android Gson（snake_case、毫秒時間戳）一致 */
export function toMobileMessage(msg: MessageWithSender): Record<string, unknown> {
  const s = msg.sender;
  return {
    id: msg.id,
    chat_id: msg.chatId,
    sender_id: msg.senderId,
    sender_name: s?.name ?? '',
    sender_avatar: s?.avatarUrl ?? '',
    content: msg.content ?? '',
    type: msg.type,
    client_message_id: msg.clientMessageId ?? null,
    read_at: msg.readAt ? new Date(msg.readAt).getTime() : null,
    created_at: msg.createdAt ? new Date(msg.createdAt).getTime() : Date.now(),
  };
}

export function toMobileChat(chat: ChatWithRels, currentUserId: string): Record<string, unknown> {
  const participants = chat.participants ?? [];
  const other = participants.find((p) => p.id !== currentUserId);
  const item = chat.item;
  // 優先使用 service 層計算後夾帶的 lastMessage / unreadCount，
  // fallback 才用 messages array（建立 chat 立刻回傳時會走 fallback）
  const last =
    chat.lastMessage ?? (chat.messages && chat.messages[0]) ?? null;
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
