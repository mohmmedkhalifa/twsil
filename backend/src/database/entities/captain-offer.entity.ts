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

export enum OfferStatus {
  Pending = 'pending',
  Accepted = 'accepted',
  Rejected = 'rejected',
  Cancelled = 'cancelled',
}

@Entity('captain_offers')
@Index(['orderId', 'captainId'], { unique: true })
export class CaptainOffer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  orderId: string;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'orderId' })
  order: Order;

  @Column()
  @Index()
  captainId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'captainId' })
  captain: User;

  @Column('float')
  price: number;

  @Column({ default: 30 })
  estimatedTimeMinutes: number;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  @Column({ type: 'simple-enum', enum: OfferStatus, default: OfferStatus.Pending })
  status: OfferStatus;

  @Column({ default: false })
  isDirectRequest: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
