import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import {
  CancelOrderDto,
  CreateOrderDto,
  OrdersService,
  RateOrderDto,
  ReviewOrderPaymentDto,
  SubmitOrderPaymentDto,
} from './orders.service';

@Controller('orders')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post()
  @Roles(UserRole.Customer)
  create(@CurrentUser() user: { id: string }, @Body() dto: CreateOrderDto) {
    return this.orders.create(user.id, dto);
  }

  @Get('mine')
  myOrders(@CurrentUser() user: { id: string; role: UserRole }) {
    return this.orders.myOrders(user.id, user.role);
  }

  @Get('available')
  @Roles(UserRole.Captain)
  available(@CurrentUser() user: { id: string }) {
    return this.orders.availableOrders(user.id);
  }

  @Get('available/:id')
  @Roles(UserRole.Captain)
  availableDetail(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.orders.availableOrderDetail(user.id, id);
  }

  @Post(':id/payments')
  @Roles(UserRole.Customer)
  submitPayment(@CurrentUser() user: { id: string }, @Param('id') id: string, @Body() dto: SubmitOrderPaymentDto) {
    return this.orders.submitPayment(user.id, id, dto);
  }

  @Post(':id/accept')
  @Roles(UserRole.Captain)
  accept(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.orders.acceptOrder(user.id, id);
  }

  @Post(':id/transition')
  @Roles(UserRole.Captain)
  transition(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() body: { action: string; code?: string },
  ) {
    return this.orders.transition(user.id, id, body.action, body.code);
  }

  @Post(':id/delivered')
  markDelivered(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.orders.markDelivered(id, user.id);
  }

  @Post(':id/location')
  @Roles(UserRole.Captain)
  updateLocation(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() body: { lat: number; lng: number },
  ) {
    return this.orders.updateLocation(user.id, id, body.lat, body.lng);
  }

  @Post(':id/rate')
  rate(@CurrentUser() user: { id: string }, @Param('id') id: string, @Body() dto: RateOrderDto) {
    return this.orders.rate(user.id, id, dto);
  }

  @Post(':id/cancel')
  @Roles(UserRole.Customer)
  cancel(@CurrentUser() user: { id: string }, @Param('id') id: string, @Body() dto: CancelOrderDto) {
    return this.orders.cancel(user.id, id, dto);
  }

  @Get('admin/list')
  @Roles(UserRole.Admin)
  adminList(@Query('status') status?: string) {
    return this.orders.listAll(status as never);
  }

  @Get('admin/payments')
  @Roles(UserRole.Admin)
  adminPayments(@Query('status') status?: string) {
    return this.orders.listOrderPayments(status as never);
  }

  @Post('admin/payments/:paymentId/review')
  @Roles(UserRole.Admin)
  adminReviewPayment(
    @CurrentUser() user: { id: string },
    @Param('paymentId') paymentId: string,
    @Body() dto: ReviewOrderPaymentDto,
  ) {
    return this.orders.reviewOrderPayment(user.id, paymentId, dto);
  }

  @Get(':id')
  detail(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.orders.detail(id, user.id);
  }
}