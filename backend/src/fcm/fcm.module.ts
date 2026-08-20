import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { FcmService } from './fcm.service';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [FcmService],
  exports: [FcmService],
})
export class FcmModule {}