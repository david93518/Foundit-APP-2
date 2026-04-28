import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { User } from './user.entity';
import { Chat } from './chat.entity';

export enum ItemType {
  LOST = 'LOST',
  FOUND = 'FOUND',
}

export enum ItemStatus {
  ACTIVE = 'ACTIVE',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED',
}

@Entity('items')
@Index('idx_items_status_created', ['status', 'createdAt'])
@Index('idx_items_user', ['userId'])
@Index('idx_items_type_status', ['type', 'status'])
@Index('idx_items_category', ['category'])
export class Item {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: ItemType })
  type: ItemType;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, (user) => user.items, { eager: false })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ length: 100 })
  title: string;

  @Column({ length: 50 })
  category: string;

  @Column({ type: 'text', default: '' })
  description: string;

  @Column({ length: 30, default: '' })
  color: string;

  @Column({ type: 'text', array: true, default: [] })
  images: string[];

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ name: 'location_name', default: '' })
  locationName: string;

  @Column({ name: 'lost_at', type: 'timestamptz', nullable: true })
  lostAt: Date;

  @Column({ default: 0 })
  reward: number;

  @Column({ name: 'has_reward', default: false })
  hasReward: boolean;

  @Column({ name: 'storage_location', default: '' })
  storageLocation: string;

  @Column({ name: 'handed_to_police', default: false })
  handedToPolice: boolean;

  @Column({ type: 'enum', enum: ItemStatus, default: ItemStatus.ACTIVE })
  status: ItemStatus;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => Chat, (chat) => chat.item)
  chats: Chat[];
}
