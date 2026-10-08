import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Chat } from '../common/entities/chat.entity';
import { Message, MessageType } from '../common/entities/message.entity';
import { NotificationType } from '../common/entities/notification.entity';
import { User } from '../common/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { PushService } from '../push/push.service';

type ChatWithRels = Chat & { participants?: User[] };

/**
 * 聊天的推播。一律在背景執行：推播失敗或未設定不影響訊息本身。
 * 前景時是否顯示由 App 決定（正在看這個對話就不打擾）。
 */
@Injectable()
export class ChatPushService {
  private readonly logger = new Logger(ChatPushService.name);

  constructor(
    private readonly push: PushService,
    private readonly notifications: NotificationsService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  /** badge：收件人目前的未讀總數，由呼叫端計算。 */
  async newMessage(
    chat: ChatWithRels,
    message: Message,
    sender: User,
    unreadFor: (userId: string) => Promise<number>,
  ): Promise<void> {
    const subject = this.subject(chat);
    for (const recipient of this.recipients(chat, sender.id)) {
      await this.deliver(recipient, {
        title: subject ? `${this.name(sender)} · ${subject}` : this.name(sender),
        body: this.preview(message),
        data: { type: 'chat_message', chat_id: chat.id },
        collapseKey: `chat-${chat.id}`,
        badge: await unreadFor(recipient.id),
      });
    }
  }

  /** 有人掃到防丟牌並開了對話：同時留一筆站內通知，拒絕推播的人也看得到。 */
  async tagScanned(chat: ChatWithRels, finder: User, tagName: string): Promise<void> {
    const owner = this.recipients(chat, finder.id)[0];
    if (!owner) return;
    const title = '有人掃到你的防丟牌';
    const content = `${this.name(finder)} 掃描了「${tagName}」，點開回覆對方。`;
    await this.notifications.create({
      userId: owner.id,
      type: NotificationType.QR_SCAN,
      title,
      content,
      chatId: chat.id,
    });
    await this.deliver(owner, {
      title,
      body: content,
      data: { type: 'chat_message', chat_id: chat.id },
      collapseKey: `chat-${chat.id}`,
    });
  }

  private recipients(chat: ChatWithRels, senderId: string): User[] {
    return (chat.participants ?? []).filter((p) => p.id !== senderId && p.status === 'active');
  }

  private async deliver(recipient: User, message: Parameters<PushService['send']>[1]): Promise<void> {
    if (!this.push.enabled || !recipient.fcmToken) return;
    const result = await this.push.send(recipient.fcmToken, message);
    if (result === 'invalid-token') {
      // 只清掉仍是同一個 token 的紀錄，避免覆蓋使用者剛更新的新 token。
      await this.userRepo.update({ id: recipient.id, fcmToken: recipient.fcmToken }, { fcmToken: null });
      this.logger.log(`已移除失效的推播 token user=${recipient.id}`);
    }
  }

  private subject(chat: Chat): string {
    return chat.item?.title ?? chat.qrItem?.name ?? '';
  }

  private name(user: User): string {
    return user.name?.trim() || 'FOUND !T 用戶';
  }

  private preview(message: Message): string {
    switch (message.type) {
      case MessageType.IMAGE:
        return '傳送了一張照片';
      case MessageType.LOCATION:
        return '分享了一個位置';
      default: {
        const text = message.content.replace(/\s+/g, ' ').trim();
        return text.length > 120 ? `${text.slice(0, 119)}…` : text;
      }
    }
  }
}
