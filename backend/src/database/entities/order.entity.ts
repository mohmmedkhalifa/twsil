import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { User } from './user.entity';
import { timestampType } from './column-types';
import { OrderPayment } from './order-payment.entity';
import { OrderTimeline } from './order-timeline.entity';

export enum OrderStatus {
  PaymentPending = 'payment_pending',
  AwaitingCaptain = 'awaiting_captain',
  CaptainAssigned = 'captain_assigned',
  EnRoutePickup = 'en_route_pickup',
  ArrivedPickup = 'arrived_pickup',
  PickedUp = 'picked_up',
  EnRouteDelivery = 'en_route_delivery',
  ArrivedDropoff = 'arrived_dropoff',
  Delivered = 'delivered',
  Completed = 'completed',
  Cancelled = 'cancelled',
}

export enum PackageSize {
  Small = 'small',
  Medium = 'medium',
  Large = 'large',
}

@Entity('orders')
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  orderNumber: string;

  @Column()
  @Index()
  customerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'customerId' })
  customer: User;

  @Column({ type: 'text', nullable: true })
  @Index()
  captainId: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'captainId' })
  captain: User | null;

  @Column('float')
  pickupLat: number;

  @Column('float')
  pickupLng: number;

  @Column()
  pickupAddress: string;

  @Column('float')
  dropoffLat: number;

  @Column('float')
  dropoffLng: number;

  @Column()
  dropoffAddress: string;

  @Column({ type: 'text' })
  packageDescription: string;

  @Column({ type: 'simple-enum', enum: PackageSize, default: PackageSize.Medium })
  packageSize: PackageSize;

  @Column({ type: 'float', default: 0 })
  weightKg: number;

  @Column({ type: 'float', default: 0 })
  distanceKm: number;

  @Column({ type: 'float' })
  deliveryFee: number;

  @Column({ type: 'float' })
  serviceFee: number;

  @Column({ type: 'simple-enum', enum: OrderStatus, default: OrderStatus.PaymentPending })
  @Index()
  status: OrderStatus;

  @Column({ type: 'text', nullable: true })
  cancellationReason: string | null;

  @Column({ type: 'text', nullable: true })
  cancelledByUserId: string | null;

  @Column({ type: 'float', nullable: true })
  currentLat: number | null;

  @Column({ type: 'float', nullable: true })
  currentLng: number | null;

  @Column({ type: timestampType() as never, nullable: true })
  lastTrackingAt: Date | null;

  @Column({ nullable: true })
  pickupCode: string;

  @Column({ default: false })
  ratedByCustomer: boolean;

  @Column({ default: false })
  ratedByCaptain: boolean;

  @Column({ default: false })
  deliveredConfirmedByCustomer: boolean;

  @OneToMany(() => OrderPayment, (p) => p.order, { cascade: true })
  payments: OrderPayment[];

  @OneToMany(() => OrderTimeline, (t) => t.order, { cascade: true })
  timeline: OrderTimeline[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}