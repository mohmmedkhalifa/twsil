import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { CaptainProfile } from './captain-profile.entity';

export enum UserRole {
  Customer = 'customer',
  Captain = 'captain',
  Admin = 'admin',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column({ unique: true })
  @Index()
  phone: string;

  @Column({ type: 'text', nullable: true })
  email: string | null;

  @Column({ select: false, nullable: true })
  passwordHash: string;

  @Column({ type: 'simple-enum', enum: UserRole, default: UserRole.Customer })
  role: UserRole;

  @Column({ type: 'text', nullable: true })
  avatarUrl: string | null;

  @Column({ default: 'ar' })
  locale: string;

  @Column({ default: false })
  isPhoneVerified: boolean;

  @Column({ type: 'text', nullable: true })
  fcmToken: string | null;

  @Column({ default: false })
  isBanned: boolean;

  @OneToOne(() => CaptainProfile, (profile) => profile.user, { cascade: true })
  captainProfile: CaptainProfile;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}