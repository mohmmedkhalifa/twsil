import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthService, LoginDto, RegisterCaptainDto, RegisterCustomerDto } from './auth.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterCustomerDto) {
    return this.authService.registerCustomer(dto);
  }

  @Post('register/captain')
  registerCaptain(@Body() dto: RegisterCaptainDto) {
    return this.authService.registerCaptain(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: { id: string }) {
    return this.authService.me(user.id);
  }

  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  updateProfile(@CurrentUser() user: { id: string }, @Body() dto: unknown) {
    return this.authService.updateProfile(user.id, dto as any);
  }

  @Post('fcm-token')
  @UseGuards(JwtAuthGuard)
  setFcmToken(@CurrentUser() user: { id: string }, @Body() body: { token: string }) {
    return this.authService.setFcmToken(user.id, body.token);
  }
}