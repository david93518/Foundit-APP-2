import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification, NotificationType } from '../common/entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notifRepo: Repository<Notification>,
  ) {}

  async findAllByUser(
    userId: string,
    take = 50,
    skip = 0,
  ): Promise<Notification[]> {
    return this.notifRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take,
      skip,
    });
  }

  async unreadCountForUser(userId: string): Promise<number> {
    return this.notifRepo.count({ where: { userId, isRead: false } });
  }

  async markRead(id: string, userId: string): Promise<void> {
    await this.notifRepo.update({ id, userId }, { isRead: true });
  }

  async markAllRead(userId: string): Promise<void> {
    await this.notifRepo.update({ userId, isRead: false }, { isRead: true });
  }

  /** 供內部呼叫建立通知 */
  async create(params: {
    userId: string;
    type: NotificationType;
    title: string;
    content: string;
    itemId?: string;
    chatId?: string;
  }): Promise<Notification> {
    const notif = this.notifRepo.create(params);
    return this.notifRepo.save(notif);
  }
}
