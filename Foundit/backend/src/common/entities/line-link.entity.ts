import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * LINE 官方帳號發給撿到東西的人的一次性連結。
 * 只存雜湊：資料庫外洩也拿不到可用的連結，也看不出是哪個 LINE 使用者。
 */
@Entity('line_links')
@Index('idx_line_links_user_created', ['lineUserHash', 'createdAt'])
export class LineLink {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'token_hash', type: 'varchar', length: 64, unique: true })
  tokenHash: string;

  @Column({ name: 'line_user_hash', type: 'varchar', length: 64 })
  lineUserHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'uses_left', type: 'int' })
  usesLeft: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
