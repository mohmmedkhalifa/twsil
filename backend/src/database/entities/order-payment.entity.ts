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
import { Order } from './order.entity';
import { User } from './user.entity';
import { timestampType } from './column-types';
import { PaymentMethod, PaymentStatus } from './subscription.entity';

@Entity('order_payments')
export class OrderPayment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  orderId: string;

  @ManyToOne(() => Order, (order) => order.payments)
  @JoinColumn({ name: 'orderId' })
  order: Order;

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

  @Column({
    type: 'simple-enum',
    enum: PaymentStatus,
    default: PaymentStatus.AwaitingPayment,
  })
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

  @UpdateDateColumn()
  updatedAt: Date;
}