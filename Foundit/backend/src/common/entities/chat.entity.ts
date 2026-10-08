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
} from 'typeorm';
import { User } from './user.entity';
import { Item } from './item.entity';
import { Message } from './message.entity';

@Entity('chats')
@Index('uniq_chat_item_requester', ['itemId', 'requesterId'], { unique: true })
export class Chat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'item_id' })
  itemId: string;

  /** 主動聯絡的人。與 item 組成唯一對話，避免並發重複建房。 */
  @Column({ name: 'requester_id', type: 'uuid', nullable: true })
  requesterId: string | null;

  @ManyToOne(() => Item, (item) => item.chats, { eager: false })
  @JoinColumn({ name: 'item_id' })
  item: Item;

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
