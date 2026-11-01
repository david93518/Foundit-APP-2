import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  Check,
} from 'typeorm';
import { User } from './user.entity';
import { QrBatch } from './qr-batch.entity';

// 約束與索引由 BoundQrAndLine migration 建立；這裡宣告是為了讓開發環境的 synchronize 不會把它們拿掉。
@Entity('qr_items')
@Index('idx_qr_items_user', ['userId'])
@Index('idx_qr_items_batch', ['batchId'])
@Check('chk_qr_bound_owner', '("user_id" IS NULL) = ("bound_at" IS NULL)')
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

  @ManyToOne(() => QrBatch, { nullable: true })
  @JoinColumn({ name: 'batch_id', foreignKeyConstraintName: 'fk_qr_item_batch' })
  batch?: QrBatch | null;

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
