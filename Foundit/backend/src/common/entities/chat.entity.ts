import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  ManyToMany,
  JoinTable,
  Index,
  Check,
} from 'typeorm';
import { User } from './user.entity';
import { Item } from './item.entity';
import { Message } from './message.entity';
import { QrItem } from './qr-item.entity';

@Entity('chats')
@Index('uniq_chat_item_requester', ['itemId', 'requesterId'], { unique: true })
@Index('uniq_chat_qr_requester', ['qrItemId', 'requesterId'], { unique: true })
@Check('chk_chat_subject', 'num_nonnulls("item_id", "qr_item_id") = 1')
export class Chat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** 對話主題二選一：刊登物品，或掃到的防丟牌。 */
  @Column({ name: 'item_id', type: 'uuid', nullable: true })
  itemId: string | null;

  @Column({ name: 'qr_item_id', type: 'uuid', nullable: true })
  qrItemId: string | null;

  /** 主動聯絡的人。與 item 組成唯一對話，避免並發重複建房。 */
  @Column({ name: 'requester_id', type: 'uuid', nullable: true })
  requesterId: string | null;

  @ManyToOne(() => Item, (item) => item.chats, { eager: false })
  @JoinColumn({ name: 'item_id' })
  item: Item | null;

  @ManyToOne(() => QrItem, { eager: false })
  @JoinColumn({ name: 'qr_item_id', foreignKeyConstraintName: 'fk_chat_qr_item' })
  qrItem: QrItem | null;

  @ManyToMany(() => User)
  @JoinTable({
    name: 'chat_participants',
    joinColumn: { name: 'chat_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'user_id', referencedColumnName: 'id' },
  })
  participants: User[];

  @OneToMany(() => Message, (msg) => msg.chat)
  messages: Message[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
