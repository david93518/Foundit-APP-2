import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('qr_items')
export class QrItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.qrItems)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 100 })
  name: string;

  @Column({ type: 'text', default: '' })
  description: string;

  /** 穩定代碼。查找以這個欄位為準，不把網域拼進主鍵。 */
  @Column({ type: 'varchar', length: 80, unique: true, nullable: true })
  code: string | null;

  @Column({ name: 'qr_code', unique: true })
  qrCode: string;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @Column({ name: 'qr_image_url', default: '' })
  qrImageUrl: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
