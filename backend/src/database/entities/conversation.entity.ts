import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Order } from './order.entity';
import { User } from './user.entity';
import { Message } from './message.entity';
import { CaptainOffer } from './captain-offer.entity';

@Entity('conversations')
@Index(['orderId', 'captainId'], { unique: true })
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index()
  orderId: string;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'orderId' })
  order: Order;

  @Column()
  customerId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'customerId' })
  customer: User;

  @Column({ type: 'text', nullable: true })
  captainId: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'captainId' })
  captain: User;

  @Column({ type: 'uuid', nullable: true })
  offerId: string | null;

  @ManyToOne(() => CaptainOffer, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'offerId' })
  offer: CaptainOffer | null;

  @OneToMany(() => Message, (m) => m.conversation)
  messages: Message[];

  @CreateDateColumn()
  createdAt: Date;
}