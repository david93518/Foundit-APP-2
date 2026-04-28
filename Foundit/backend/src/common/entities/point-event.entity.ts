import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { UserPoints } from './user-points.entity';

export enum PointEventType {
  FOUND_ITEM = 'found_item',
  MATCH_SUCCESS = 'match_success',
  DAILY_LOGIN = 'daily_login',
  QR_SCAN = 'qr_scan',
  REWARD_RECEIVED = 'reward_received',
}

@Entity('point_events')
export class PointEvent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_points_id' })
  userPointsId: string;

  @ManyToOne(() => UserPoints, (up) => up.events)
  @JoinColumn({ name: 'user_points_id' })
  userPoints: UserPoints;

  @Column({ type: 'enum', enum: PointEventType })
  type: PointEventType;

  @Column()
  points: number;

  @Column({ type: 'text', default: '' })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
