import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  CaptainProfile,
  SubscriptionStatus,
  VerificationStatus,
} from '../database/entities/captain-profile.entity';
import { User, UserRole } from '../database/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

export class UpdateCaptainDto {
  transportType?: string;
  plateNumber?: string;
  city?: string;
  bio?: string;
  isAvailable?: boolean;
}

export class SubmitVerificationDto {
  nationalIdCardImageUrl: string;
  licenseImageUrl?: string;
  nationalId?: string;
}

@Injectable()
export class CaptainsService {
  constructor(
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async me(userId: string) {
    const profile = await this.captainsRepo.findOne({
      where: { userId },
      relations: { user: true },
    });
    if (!profile) throw new NotFoundException('Captain profile not found');
    return this.serialize(profile);
  }

  async update(userId: string, dto: UpdateCaptainDto) {
    const profile = await this.captainsRepo.findOne({ where: { userId } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    if (dto.isAvailable === true && profile.subscriptionStatus !== SubscriptionStatus.Active) {
      throw new BadRequestException('Your subscription must be active to receive orders');
    }
    await this.captainsRepo.update(profile.id, {
      ...(dto.transportType ? { transportType: dto.transportType as never } : {}),
      ...(dto.plateNumber !== undefined ? { plateNumber: dto.plateNumber } : {}),
      ...(dto.city !== undefined ? { city: dto.city } : {}),
      ...(dto.bio !== undefined ? { bio: dto.bio } : {}),
      ...(dto.isAvailable !== undefined ? { isAvailable: dto.isAvailable } : {}),
    });
    if (dto.isAvailable !== undefined) {
      await this.broadcastAvailability(userId);
    }
    return this.me(userId);
  }

  async setAvailability(userId: string, isAvailable: boolean) {
    const profile = await this.captainsRepo.findOne({ where: { userId } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    if (isAvailable && profile.subscriptionStatus !== SubscriptionStatus.Active) {
      throw new BadRequestException('Your subscription must be active to receive orders');
    }
    await this.captainsRepo.update(profile.id, { isAvailable });
    await this.broadcastAvailability(userId);
    return this.me(userId);
  }

  private async broadcastAvailability(userId: string) {
    const profile = await this.captainsRepo.findOne({
      where: { userId },
      relations: { user: true },
    });
    if (!profile) return;
    const payload = this.toPublicProfile(profile);
    // Customers immediately see/remove the captain from the available list.
    this.realtime.sendToCustomers('captain:availability', payload);
    // Peers & the captain's own other devices stay in sync too.
    this.realtime.broadcast('captain:availability', payload);
  }

  toPublicProfile(profile: CaptainProfile & { user?: User }) {
    return {
      id: profile.userId,
      userId: profile.userId,
      firstName: profile.user?.firstName ?? 'كابتن',
      lastName: profile.user?.lastName ?? '',
      avatarUrl: profile.user?.avatarUrl,
      rating: profile.rating,
      totalDeliveries: profile.totalDeliveries,
      transportType: profile.transportType,
      isAvailable: profile.isAvailable,
      lastLat: profile.lastLat,
      lastLng: profile.lastLng,
    };
  }

  async submitVerification(userId: string, dto: SubmitVerificationDto) {
    const profile = await this.captainsRepo.findOne({ where: { userId } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    if (!dto.nationalIdCardImageUrl) {
      throw new BadRequestException('National ID card image is required');
    }
    await this.captainsRepo.update(profile.id, {
      verificationStatus: VerificationStatus.Pending,
      verificationNote: null,
      nationalId: dto.nationalId ?? profile.nationalId,
    });

    const admins = await this.usersRepo.find({ where: { role: UserRole.Admin } });
    await this.notifications.push(
      admins.map((a) => a.id),
      'captain:verification',
      'تحقق جديد من سائق',
      'سائق بانتظار التحقق من الوثائق الشخصية.',
      { captainId: profile.userId },
    );
    await this.notifications.push(
      [userId],
      'captain:verification_submitted',
      'تم إرسال الوثائق',
      'تم إرسال وثائقك للمراجعة، وسيتم إشعارك عند اكتمال التحقق.',
    );
    return this.me(userId);
  }

  async availableCaptains() {
    return this.captainsRepo.find({
      where: {
        isAvailable: true,
        verificationStatus: VerificationStatus.Approved,
        isActive: true,
      },
      relations: { user: true },
    });
  }

  async getAvailableCaptainsNearby(lat?: number, lng?: number, maxRadiusKm: number = 15) {
    const captains = await this.captainsRepo.find({
      where: { isAvailable: true, isActive: true, verificationStatus: VerificationStatus.Approved },
      relations: { user: true },
    });

    return captains.map((c) => {
      let distanceKm = 0;
      if (lat != null && lng != null && c.lastLat != null && c.lastLng != null) {
        distanceKm = this.calculateHaversine(lat, lng, c.lastLat, c.lastLng);
      }
      return {
        ...this.toPublicProfile(c),
        distanceKm: Math.round(distanceKm * 10) / 10,
      };
    }).filter((c) => lat == null || lng == null || c.distanceKm <= maxRadiusKm);
  }

  async getPublicCaptainProfile(captainId: string, userLat?: number, userLng?: number) {
    const profile = await this.captainsRepo.findOne({
      where: { userId: captainId },
      relations: { user: true },
    });
    if (!profile) throw new NotFoundException('Captain not found');

    let distanceKm: number | null = null;
    if (userLat != null && userLng != null && profile.lastLat != null && profile.lastLng != null) {
      distanceKm = Math.round(this.calculateHaversine(userLat, userLng, profile.lastLat, profile.lastLng) * 10) / 10;
    }

    return {
      id: profile.userId,
      userId: profile.userId,
      firstName: profile.user?.firstName ?? 'كابتن',
      lastName: profile.user?.lastName ?? '',
      avatarUrl: profile.user?.avatarUrl,
      rating: profile.rating,
      totalDeliveries: profile.totalDeliveries,
      transportType: profile.transportType,
      city: profile.city,
      bio: profile.bio,
      isAvailable: profile.isAvailable,
      lastLat: profile.lastLat,
      lastLng: profile.lastLng,
      distanceKm,
    };
  }

  private calculateHaversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Earth's radius in km
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private toRad(val: number): number {
    return (val * Math.PI) / 180;
  }

  private serialize(profile: CaptainProfile & { user?: User }) {
    return {
      ...profile,
      user: profile.user
        ? {
            id: profile.user.id,
            firstName: profile.user.firstName,
            lastName: profile.user.lastName,
            phone: profile.user.phone,
            avatarUrl: profile.user.avatarUrl,
            rating: profile.rating,
          }
        : undefined,
    };
  }
}