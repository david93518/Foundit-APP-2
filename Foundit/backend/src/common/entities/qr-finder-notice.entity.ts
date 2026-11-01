import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index, ManyToOne, JoinColumn } from 'typeorm';
import { QrItem } from './qr-item.entity';

/** 撿到的人透過 LINE 留給物主的訊息紀錄，同時用來限制每個人的留言頻率。 */
@Entity('qr_finder_notices')
@Index('idx_qr_finder_notices_line_created', ['lineUserHash', 'createdAt'])
export class QrFinderNotice {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'qr_item_id', type: 'uuid' })
  qrItemId: string;

  @ManyToOne(() => QrItem)
  @JoinColumn({ name: 'qr_item_id', foreignKeyConstraintName: 'qr_finder_notices_qr_item_id_fkey' })
  qrItem?: QrItem;

  @Column({ name: 'line_user_hash', type: 'varchar', length: 64 })
  lineUserHash: string;

  @Column({ type: 'text' })
  message: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  contact: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
