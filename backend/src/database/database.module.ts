import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CaptainProfile } from '../database/entities/captain-profile.entity';
import { Subscription } from '../database/entities/subscription.entity';
import { Order } from '../database/entities/order.entity';
import { OrderPayment } from '../database/entities/order-payment.entity';
import { OrderTimeline } from '../database/entities/order-timeline.entity';
import { Conversation } from '../database/entities/conversation.entity';
import { Message } from '../database/entities/message.entity';
import { Notification } from '../database/entities/notification.entity';
import { Complaint } from '../database/entities/complaint.entity';
import { Review } from '../database/entities/review.entity';
import { CaptainOffer } from '../database/entities/captain-offer.entity';

const ENTITIES = [
  User,
  CaptainProfile,
  Subscription,
  Order,
  OrderPayment,
  OrderTimeline,
  Conversation,
  Message,
  Notification,
  Complaint,
  Review,
  CaptainOffer,
];

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      useFactory: () => {
        const isPostgres = process.env.DATABASE_TYPE === 'postgres';
        return {
          type: (isPostgres ? 'postgres' : 'better-sqlite3') as 'postgres' | 'better-sqlite3',
          database: isPostgres ? process.env.DB_NAME : 'twsil.db',
          host: process.env.DB_HOST,
          port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
          username: process.env.DB_USERNAME,
          password: process.env.DB_PASSWORD,
          ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
          extra: isPostgres ? { max: Number(process.env.DB_POOL_MAX ?? 10) } : undefined,
          entities: ENTITIES,
          synchronize: process.env.NODE_ENV !== 'production',
          autoLoadEntities: false,
        };
      },
    }),
  ],
})
export class DatabaseModule {}