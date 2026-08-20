import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import { SubscriptionsService, SubmitSubscriptionDto } from './subscriptions.service';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Post('captains/subscriptions')
  @Roles(UserRole.Captain)
  submit(@CurrentUser() user: { id: string }, @Body() dto: SubmitSubscriptionDto) {
    return this.subs.submit(user.id, dto);
  }

  @Get('captains/subscriptions')
  @Roles(UserRole.Captain)
  history(@CurrentUser() user: { id: string }) {
    return this.subs.historyForCaptain(user.id);
  }

  @Get('admin/subscriptions')
  @Roles(UserRole.Admin)
  list(@Query('status') status?: string) {
    return this.subs.listAll(status as never);
  }

  @Post('admin/subscriptions/:id/review')
  @Roles(UserRole.Admin)
  review(
    @Param('id') id: string,
    @CurrentUser() user: { id: string },
    @Body() dto: { action: 'approve' | 'reject' | 'request_receipt'; note?: string },
  ) {
    return this.subs.review(id, user.id, dto);
  }
}