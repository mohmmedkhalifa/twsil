import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Order } from '../database/entities/order.entity';
import { OrderPayment } from '../database/entities/order-payment.entity';
import { OrderTimeline } from '../database/entities/order-timeline.entity';
import { CaptainProfile } from '../database/entities/captain-profile.entity';
import { User } from '../database/entities/user.entity';
import { Conversation } from '../database/entities/conversation.entity';
import { Review } from '../database/entities/review.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { OrdersService } from './orders.service';
import { OrdersController } from './orders.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Order, OrderPayment, OrderTimeline, CaptainProfile, User, Conversation, Review]),
    NotificationsModule,
    RealtimeModule,
  ],
  providers: [OrdersService],
  controllers: [OrdersController],
  exports: [OrdersService],
})
export class OrdersModule {}