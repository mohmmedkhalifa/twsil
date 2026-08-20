import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import { CaptainsService, SubmitVerificationDto, UpdateCaptainDto } from './captains.service';

@Controller('captains')
@UseGuards(JwtAuthGuard, RolesGuard)
export class CaptainsController {
  constructor(private readonly captains: CaptainsService) {}

  @Get('me')
  @Roles(UserRole.Captain)
  me(@CurrentUser() user: { id: string }) {
    return this.captains.me(user.id);
  }

  @Patch('me')
  @Roles(UserRole.Captain)
  update(@CurrentUser() user: { id: string }, @Body() dto: UpdateCaptainDto) {
    return this.captains.update(user.id, dto);
  }

  @Post('verification')
  @Roles(UserRole.Captain)
  submitVerification(@CurrentUser() user: { id: string }, @Body() dto: SubmitVerificationDto) {
    return this.captains.submitVerification(user.id, dto);
  }

  @Get('available')
  @Roles(UserRole.Captain, UserRole.Customer, UserRole.Admin)
  available() {
    return this.captains.availableCaptains();
  }

  @Get('nearby')
  @Roles(UserRole.Captain, UserRole.Customer, UserRole.Admin)
  nearby(
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('radius') radius?: string,
  ) {
    const latNum = lat ? parseFloat(lat) : undefined;
    const lngNum = lng ? parseFloat(lng) : undefined;
    const radiusNum = radius ? parseFloat(radius) : 15;
    return this.captains.getAvailableCaptainsNearby(latNum, lngNum, radiusNum);
  }

  @Get('public/:id')
  @Roles(UserRole.Captain, UserRole.Customer, UserRole.Admin)
  getPublicProfile(
    @Param('id') id: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const latNum = lat ? parseFloat(lat) : undefined;
    const lngNum = lng ? parseFloat(lng) : undefined;
    return this.captains.getPublicCaptainProfile(id, latNum, lngNum);
  }
}