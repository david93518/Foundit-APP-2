import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

/** 一次印製的貼紙批次，方便管理員追蹤「這批貼在哪裡、印了幾張」。 */
@Entity('qr_batches')
export class QrBatch {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  label: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  place: string | null;

  @Column({ type: 'int' })
  count: number;

  @Column({ name: 'created_by', type: 'uuid', nullable: true })
  createdBy: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
