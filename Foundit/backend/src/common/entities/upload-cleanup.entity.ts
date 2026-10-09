import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

/** Committed with account erasure; removed only after filesystem cleanup succeeds. */
@Entity('upload_cleanup_jobs')
export class UploadCleanup {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' }) userId: string;
  @Column({ type: 'text', array: true, default: [] }) files: string[];
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
