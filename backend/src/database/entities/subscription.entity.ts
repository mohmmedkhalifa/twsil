import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { timestampType } from './column-types';
import { CaptainProfile } from './captain-profile.entity';

export enum PaymentMethod {
  JawwalPay = 'jawwal_pay',
  BankOfPalestine = 'bop_palestine',
  PalPay = 'palpay',
}

export enum PaymentStatus {
  AwaitingPayment = 'awaiting_payment',
  PaymentSubmitted = 'payment_submitted',
  UnderReview = 'under_review',
  Approved = 'approved',
  Rejected = 'rejected',
}

@Entity('subscriptions')
export class Subscription {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  captainId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'captainId' })
  captain: User;

  @Column({ type: 'float' })
  amount: number;

  @Column({ type: 'simple-enum', enum: PaymentMethod })
  paymentMethod: PaymentMethod;

  @Column({ type: 'text', nullable: true })
  receiptImageUrl: string | null;

  @Column({ type: 'text', nullable: true })
  transactionNumber: string | null;

  @Column({ type: timestampType() as never, nullable: true })
  transferDate: Date | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ type: 'simple-enum', enum: PaymentStatus, default: PaymentStatus.AwaitingPayment })
  @Index()
  status: PaymentStatus;

  @Column({ type: 'text', nullable: true })
  adminNote: string | null;

  @Column({ type: 'text', nullable: true })
  reviewedById: string | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'reviewedById' })
  reviewedBy: User | null;

  @Column({ type: timestampType() as never, nullable: true })
  reviewedAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}