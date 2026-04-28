-- 清空：所有物品（遺失/撿到）、聊天室、訊息、通知、QR 物品、點數與點數事件。
-- 保留 users（Google / 手機帳號可繼續登入）；並移除 seed 建立的示範帳號 0900000000。
BEGIN;

TRUNCATE TABLE
  messages,
  chat_participants,
  chats,
  notifications,
  point_events,
  user_points,
  qr_items,
  items
RESTART IDENTITY CASCADE;

DELETE FROM users WHERE phone = '0900000000';

COMMIT;
