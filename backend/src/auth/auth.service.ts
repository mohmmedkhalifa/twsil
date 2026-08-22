import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserRole } from '../database/entities/user.entity';
import { CaptainProfile, TransportType, VerificationStatus } from '../database/entities/captain-profile.entity';

export class RegisterCustomerDto {
  firstName: string;
  lastName: string;
  phone: string;
  password: string;
  locale?: 'ar' | 'en';
}

export class RegisterCaptainDto extends RegisterCustomerDto {
  transportType: TransportType;
  plateNumber?: string;
  nationalId?: string;
  city?: string;
}

export class LoginDto {
  phone: string;
  password: string;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly usersRepo: Repository<User>,
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    private readonly jwtService: JwtService,
  ) {}

  async registerCustomer(dto: RegisterCustomerDto) {
    const user = await this.register(dto, UserRole.Customer);
    return this.issueToken(user);
  }

  async registerCaptain(dto: RegisterCaptainDto) {
    const user = await this.register(dto, UserRole.Captain);
    const profile = this.captainsRepo.create({
      userId: user.id,
      transportType: dto.transportType,
      plateNumber: dto.plateNumber,
      nationalId: dto.nationalId,
      city: dto.city,
      verificationStatus: VerificationStatus.Pending,
      subscriptionStatus: SubscriptionStatus.Inactive,
      isAvailable: false,
      isActive: false,
    });
    await this.captainsRepo.save(profile);
    return this.issueToken(user);
  }

  private async register(dto: any, role: UserRole) {
    // Normalize across all clients (Mobile/Web/Admin, old builds): accept aliases
    const phone = String(dto.phone ?? dto.identifier ?? dto.mobile ?? '').trim();
    const rawPassword: unknown = dto.password ?? dto.pass ?? dto.pwd ?? dto.passwordHash;
    const password = rawPassword == null ? '' : String(rawPassword);
    const firstName = String(dto.firstName ?? dto.first_name ?? dto.name ?? '').trim();
    const lastName = String(dto.lastName ?? dto.last_name ?? '').trim();
    const locale: string = dto.locale ?? 'ar';

    if (!phone || !password || !firstName || !lastName) {
      throw new BadRequestException('All fields are required');
    }
    if (password.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters');
    }

    const exists = await this.usersRepo.findOne({ where: { phone } });
    if (exists) throw new BadRequestException('Phone number is already registered');

    const passwordHash = await bcrypt.hash(password, 10);
    if (!passwordHash) throw new BadRequestException('Failed to hash password');

    const user = this.usersRepo.create({
      firstName,
      lastName,
      phone,
      passwordHash,
      role,
      locale,
    });
    const saved = await this.usersRepo.save(user);
    delete (saved as Partial<User>).passwordHash;
    return saved;
  }

  async login(dto: LoginDto) {
    const identifier = String(dto.phone ?? (dto as any).identifier ?? (dto as any).email ?? '').trim();
    if (!identifier) {
      throw new UnauthorizedException('Phone number or email is required');
    }
    const user = await this.usersRepo.findOne({
      where: [{ phone: identifier }, { email: identifier }],
      select: { id: true, passwordHash: true, role: true, phone: true, email: true, isBanned: true, firstName: true, lastName: true, avatarUrl: true, locale: true },
    });
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (user.isBanned) throw new UnauthorizedException('Your account has been suspended');
    return this.issueToken(user);
  }

  async me(userId: string): Promise<User> {
    const user = await this.usersRepo.findOne({
      where: { id: userId },
      relations: { captainProfile: true },
    });
    if (!user) throw new UnauthorizedException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: Partial<Pick<User, 'firstName' | 'lastName' | 'locale' | 'avatarUrl' | 'fcmToken'>>) {
    await this.usersRepo.update(userId, dto as any);
    return this.me(userId);
  }

  async setFcmToken(userId: string, token: string) {
    if (!token) throw new BadRequestException('Token is required');
    await this.usersRepo.update(userId, { fcmToken: token });
    return { ok: true };
  }

  private async issueToken(user: Pick<User, 'id' | 'role'>) {
    const token = await this.jwtService.signAsync({
      sub: user.id,
      role: user.role,
    });
    const me = await this.me(user.id);
    return {
      accessToken: token,
      role: user.role,
      userId: user.id,
      user: me,
    };
  }
}