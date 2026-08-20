import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { timestampType } from './column-types';
import { Order } from './order.entity';

export enum ComplaintStatus {
  Open = 'open',
  InProgress = 'in_progress',
  Resolved = 'resolved',
  Rejected = 'rejected',
}

@Entity('complaints')
export class Complaint {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  reporterId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reporterId' })
  reporter: User;

  @Column({ type: 'text', nullable: true })
  againstUserId: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'againstUserId' })
  againstUser: User | null;

  @Column({ type: 'text', nullable: true })
  orderId: string | null;

  @ManyToOne(() => Order, { nullable: true })
  @JoinColumn({ name: 'orderId' })
  order: Order | null;

  @Column()
  subject: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'text', nullable: true })
  resolutionNote: string | null;

  @Column({ type: 'simple-enum', enum: ComplaintStatus, default: ComplaintStatus.Open })
  @Index()
  status: ComplaintStatus;

  @Column({ type: 'text', nullable: true })
  resolvedById: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'resolvedById' })
  resolvedBy: User | null;

  @Column({ type: timestampType() as never, nullable: true })
  resolvedAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}