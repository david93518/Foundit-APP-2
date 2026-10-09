import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('chat_rate_limits')
export class ChatRateLimit {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' }) userId: string;
  @Column({ name: 'window_start', type: 'timestamptz' }) windowStart: Date;
  @Column({ type: 'int' }) count: number;
}
