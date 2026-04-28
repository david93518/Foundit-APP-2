import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from './user.entity';

export enum NotificationType {
  AI_MATCH = 'AI_MATCH',
  NEW_MESSAGE = 'NEW_MESSAGE',
  NEARBY_ITEM = 'NEARBY_ITEM',
  QR_SCAN = 'QR_SCAN',
  REWARD = 'REWARD',
  SYSTEM = 'SYSTEM',
}

@Entity('notifications')
@Index('idx_notif_user_created', ['userId', 'createdAt'])
@Index('idx_notif_user_unread', ['userId', 'isRead'])
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.notifications)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: NotificationType, default: NotificationType.SYSTEM })
  type: NotificationType;

  @Column({ length: 100 })
  title: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ name: 'item_id', type: 'varchar', nullable: true })
  itemId: string | null;

  @Column({ name: 'chat_id', type: 'varchar', nullable: true })
  chatId: string | null;

  @Column({ name: 'is_read', default: false })
  isRead: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
