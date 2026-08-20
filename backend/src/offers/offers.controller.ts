import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import { CreateOfferDto, DirectRequestDto, OffersService } from './offers.service';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class OffersController {
  constructor(private readonly offersService: OffersService) {}

  @Post('orders/:id/offers')
  @Roles(UserRole.Captain)
  submitOffer(
    @CurrentUser() user: { id: string },
    @Param('id') orderId: string,
    @Body() dto: CreateOfferDto,
  ) {
    return this.offersService.createOrUpdateOffer(user.id, orderId, dto);
  }

  @Get('orders/:id/offers')
  @Roles(UserRole.Customer, UserRole.Captain, UserRole.Admin)
  getOrderOffers(
    @CurrentUser() user: { id: string },
    @Param('id') orderId: string,
  ) {
    return this.offersService.getOrderOffers(user.id, orderId);
  }

  @Post('offers/:id/accept')
  @Roles(UserRole.Customer)
  acceptOffer(
    @CurrentUser() user: { id: string },
    @Param('id') offerId: string,
  ) {
    return this.offersService.acceptOffer(user.id, offerId);
  }

  @Post('offers/:id/reject')
  @Roles(UserRole.Customer)
  rejectOffer(
    @CurrentUser() user: { id: string },
    @Param('id') offerId: string,
  ) {
    return this.offersService.rejectOffer(user.id, offerId);
  }

  @Post('captains/:id/direct-request')
  @Roles(UserRole.Customer)
  directRequest(
    @CurrentUser() user: { id: string },
    @Param('id') captainId: string,
    @Body() dto: DirectRequestDto,
  ) {
    return this.offersService.createDirectRequest(user.id, { ...dto, captainId });
  }
}
