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

  /** 貼紙綁定前沒有物主。綁定（bound_at 有值）之後才有 user_id，兩者永遠同進同出。 */
  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @ManyToOne(() => User, (user) => user.qrItems, { nullable: true })
  @JoinColumn({ name: 'user_id' })
  user: User | null;

  /** 綁定前是空字串，物主綁定時自己取名。 */
  @Column({ length: 100, default: '' })
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

  /** 印製批次。舊的自行產生貼紙沒有批次。 */
  @Column({ name: 'batch_id', type: 'uuid', nullable: true })
  batchId: string | null;

  @Column({ name: 'bound_at', type: 'timestamptz', nullable: true })
  boundAt: Date | null;

  /** 管理員停用（遺失、印錯）。停用的貼紙不能綁定，也不能被掃描。 */
  @Column({ name: 'disabled_at', type: 'timestamptz', nullable: true })
  disabledAt: Date | null;

  @Column({ name: 'qr_image_url', default: '' })
  qrImageUrl: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
