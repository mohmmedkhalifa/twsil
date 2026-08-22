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
  /** Either the phone number or the email address. */
  phone?: string;
  /** Alias accepted by clients that send `identifier`. */
  identifier?: string;
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
      verificationStatus: VerificationStatus.Approved,
      isAvailable: true,
      isActive: true,
    });
    await this.captainsRepo.save(profile);
    return this.issueToken(user);
  }

  private async register(dto: RegisterCustomerDto, role: UserRole) {
    if (!dto.phone || !dto.password || !dto.firstName || !dto.lastName) {
      throw new BadRequestException('All fields are required');
    }
    const exists = await this.usersRepo.findOne({ where: { phone: dto.phone } });
    if (exists) throw new BadRequestException('Phone number is already registered');
    const user = this.usersRepo.create({
      firstName: dto.firstName,
      lastName: dto.lastName,
      phone: dto.phone,
      passwordHash: await bcrypt.hash(dto.password, 10),
      role,
      locale: dto.locale ?? 'ar',
    });
    const saved = await this.usersRepo.save(user);
    delete (saved as Partial<User>).passwordHash;
    return saved;
  }

  async login(dto: LoginDto) {
    const raw = (dto.phone ?? dto.identifier ?? '').trim();
    const identifier = raw.toLowerCase();
    const isEmail = identifier.includes('@');
    if (!identifier) {
      throw new UnauthorizedException('Identifier (phone or email) is required');
    }
    const user = await this.usersRepo.findOne({
      where: isEmail ? { email: identifier } : { phone: raw },
      select: { id: true, passwordHash: true, role: true, phone: true, email: true, isBanned: true, firstName: true, lastName: true, avatarUrl: true, locale: true },
    });
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid phone or password');
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