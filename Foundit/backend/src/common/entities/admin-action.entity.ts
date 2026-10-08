import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

/** 只追加、不提供修改或刪除 API。 */
@Entity('admin_actions')
export class AdminAction {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'actor_id', type: 'uuid' })
  actorId: string;

  @Column({ type: 'varchar', length: 64 })
  action: string;

  @Column({ name: 'target_type', type: 'varchar', length: 32 })
  targetType: string;

  @Column({ name: 'target_id', type: 'varchar', length: 64 })
  targetId: string;

  @Column({ type: 'text', default: '' })
  reason: string;

  @Column({ type: 'varchar', length: 32, default: '' })
  result: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
