import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import { VerificationStatus } from '../database/entities/captain-profile.entity';
import { OrdersService } from '../orders/orders.service';
import { AdminService, ReviewCaptainVerificationDto } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.Admin)
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly ordersService: OrdersService,
  ) {}

  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @Get('captains')
  captains(@Query('status') status?: string) {
    return this.admin.listCaptains(status as VerificationStatus | undefined);
  }

  @Get('captains/:id')
  captainDetail(@Param('id') id: string) {
    return this.admin.captainDetail(id);
  }

  @Post('captains/:userId/verification')
  reviewVerification(
    @Param('userId') userId: string,
    @CurrentUser() user: { id: string },
    @Body() dto: ReviewCaptainVerificationDto,
  ) {
    return this.admin.reviewCaptainVerification(userId, user.id, dto);
  }

  @Post('captains/:userId/toggle-active')
  toggleCaptainActive(@Param('userId') userId: string) {
    return this.admin.toggleCaptainActive(userId);
  }

  @Get('users')
  users(@Query('role') role?: string) {
    return this.admin.listUsers(role as UserRole | undefined);
  }

  @Post('users/:id/toggle-ban')
  toggleBan(@Param('id') id: string) {
    return this.admin.toggleBan(id);
  }

  @Get('reviews')
  reviews() {
    return this.admin.listReviews();
  }

  @Post('reviews/:id/toggle-hide')
  hideReview(@Param('id') id: string) {
    return this.admin.hideReview(id);
  }

  @Get('payments')
  payments() {
    return this.admin.listPayments();
  }

  @Post('payments/:id/review')
  reviewPayment(
    @Param('id') id: string,
    @CurrentUser() user: { id: string },
    @Body() dto: { action: 'approve' | 'reject' | 'request_receipt'; note?: string },
  ) {
    return this.ordersService.reviewOrderPayment(user.id, id, dto);
  }

  @Get('orders')
  orders(@Query('status') status?: string) {
    return this.admin.listOrders(status);
  }
}