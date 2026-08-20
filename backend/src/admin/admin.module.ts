import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CaptainProfile } from '../database/entities/captain-profile.entity';
import { User } from '../database/entities/user.entity';
import { Order } from '../database/entities/order.entity';
import { OrderPayment } from '../database/entities/order-payment.entity';
import { Subscription } from '../database/entities/subscription.entity';
import { Review } from '../database/entities/review.entity';
import { Complaint } from '../database/entities/complaint.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersModule } from '../orders/orders.module';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      CaptainProfile,
      User,
      Order,
      OrderPayment,
      Subscription,
      Review,
      Complaint,
    ]),
    NotificationsModule,
    OrdersModule,
  ],
  providers: [AdminService],
  controllers: [AdminController],
})
export class AdminModule {}