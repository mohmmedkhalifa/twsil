import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { timestampType } from './column-types';

export enum TransportType {
  Car = 'car',
  Motorcycle = 'motorcycle',
  Bicycle = 'bicycle',
  Other = 'other',
}

export enum VerificationStatus {
  Pending = 'pending',
  Approved = 'approved',
  Rejected = 'rejected',
}

export enum SubscriptionStatus {
  Inactive = 'inactive',
  Submitted = 'submitted',
  UnderReview = 'under_review',
  Active = 'active',
  Rejected = 'rejected',
}

@Entity('captain_profiles')
export class CaptainProfile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @OneToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'simple-enum', enum: TransportType })
  transportType: TransportType;

  @Column({ type: 'text', nullable: true })
  plateNumber: string | null;

  @Column({ type: 'text', nullable: true })
  nationalId: string | null;

  @Column({ type: 'text', nullable: true })
  city: string | null;

  @Column({ nullable: true, type: 'text' })
  bio: string | null;

  @Column({ type: 'simple-enum', enum: VerificationStatus, default: VerificationStatus.Pending })
  verificationStatus: VerificationStatus;

  @Column({ nullable: true, type: 'text' })
  verificationNote: string | null;

  @Column({ default: false })
  idCardVerified: boolean;

  @Column({ default: false })
  licenseVerified: boolean;

  @Column({ type: 'simple-enum', enum: SubscriptionStatus, default: SubscriptionStatus.Inactive })
  subscriptionStatus: SubscriptionStatus;

  @Column({ type: timestampType() as never, nullable: true })
  subscriptionExpiresAt: Date | null;

  @Column({ default: false })
  isAvailable: boolean;

  @Column({ type: 'float', default: 0 })
  rating: number;

  @Column({ default: 0 })
  ratingCount: number;

  @Column({ default: 0 })
  totalDeliveries: number;

  @Column({ type: 'float', default: 0 })
  totalEarnings: number;

  @Column({ default: true })
  isActive: boolean;

  @Column({ type: 'text', nullable: true })
  nationalIdCardImageUrl: string | null;

  @Column({ type: 'text', nullable: true })
  licenseImageUrl: string | null;

  @Column({ type: 'float', nullable: true })
  lastLat: number | null;

  @Column({ type: 'float', nullable: true })
  lastLng: number | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}