import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CaptainOffer } from '../database/entities/captain-offer.entity';
import { Order } from '../database/entities/order.entity';
import { Conversation } from '../database/entities/conversation.entity';
import { CaptainProfile } from '../database/entities/captain-profile.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { OffersService } from './offers.service';
import { OffersController } from './offers.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([CaptainOffer, Order, Conversation, CaptainProfile]),
    NotificationsModule,
    RealtimeModule,
  ],
  providers: [OffersService],
  controllers: [OffersController],
  exports: [OffersService],
})
export class OffersModule {}
