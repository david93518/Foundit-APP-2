import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Item } from './item.entity';
import { Chat } from './chat.entity';
import { Message } from './message.entity';
import { Notification } from './notification.entity';
import { QrItem } from './qr-item.entity';
import { UserPoints } from './user-points.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 100 })
  phone: string;

  /** Google OpenID subject，每個 Google 帳號唯一；用於正確區分 A/B 與聊天參與者 */
  @Column({ name: 'google_sub', type: 'varchar', length: 128, nullable: true, unique: true })
  googleSub: string | null;

  @Column({ length: 50, default: '' })
  name: string;

  @Column({ name: 'avatar_url', default: '' })
  avatarUrl: string;

  /** 自我介紹（編輯個人檔案頁顯示） */
  @Column({ type: 'text', default: '' })
  bio: string;

  /** 進階聯絡資料 — 暫無驗證流程，僅儲存 */
  @Column({ length: 120, default: '' })
  email: string;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;

  @Column({ name: 'fcm_token', type: 'varchar', nullable: true })
  fcmToken: string | null;

  /** 登出、停權、刪帳時遞增，讓舊 access token 失效。 */
  @Column({ name: 'token_version', type: 'int', default: 0 })
  tokenVersion: number;

  @Column({ type: 'varchar', length: 20, default: 'user' })
  role: string;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @Column({ name: 'terms_version', type: 'varchar', length: 32, default: '' })
  termsVersion: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => Item, (item) => item.user)
  items: Item[];

  @OneToMany(() => Notification, (n) => n.user)
  notifications: Notification[];

  @OneToMany(() => QrItem, (q) => q.user)
  qrItems: QrItem[];

  @OneToMany(() => Message, (m) => m.sender)
  messages: Message[];
}
