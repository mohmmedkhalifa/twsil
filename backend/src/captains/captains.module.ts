import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CaptainProfile } from '../database/entities/captain-profile.entity';
import { User } from '../database/entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { CaptainsService } from './captains.service';
import { CaptainsController } from './captains.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([CaptainProfile, User]),
    NotificationsModule,
    RealtimeModule,
  ],
  providers: [CaptainsService],
  controllers: [CaptainsController],
  exports: [CaptainsService],
})
export class CaptainsModule {}