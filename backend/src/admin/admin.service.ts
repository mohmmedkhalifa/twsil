import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  CaptainProfile,
  SubscriptionStatus,
  VerificationStatus,
} from '../database/entities/captain-profile.entity';
import { User, UserRole } from '../database/entities/user.entity';
import { Order, OrderStatus } from '../database/entities/order.entity';
import { OrderPayment } from '../database/entities/order-payment.entity';
import { Subscription } from '../database/entities/subscription.entity';
import { Review } from '../database/entities/review.entity';
import { Complaint } from '../database/entities/complaint.entity';
import { PaymentMethod, PaymentStatus } from '../database/entities/subscription.entity';
import { NotificationsService } from '../notifications/notifications.service';

export class ReviewCaptainVerificationDto {
  action: 'approve' | 'reject';
  note?: string;
}

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    @InjectRepository(Order)
    private readonly ordersRepo: Repository<Order>,
    @InjectRepository(OrderPayment)
    private readonly paymentsRepo: Repository<OrderPayment>,
    @InjectRepository(Subscription)
    private readonly subsRepo: Repository<Subscription>,
    @InjectRepository(Review)
    private readonly reviewsRepo: Repository<Review>,
    @InjectRepository(Complaint)
    private readonly complaintsRepo: Repository<Complaint>,
    private readonly notifications: NotificationsService,
  ) {}

  async stats() {
    const [
      usersCount,
      captainsCount,
      customersCount,
      awaitingCaptainCount,
      activeOrdersCount,
      deliveredCount,
      totalOrdersCount,
      pendingVerification,
      pendingSubscriptions,
      pendingPayments,
      revenue,
    ] = await Promise.all([
      this.usersRepo.count(),
      this.usersRepo.count({ where: { role: UserRole.Captain } }),
      this.usersRepo.count({ where: { role: UserRole.Customer } }),
      this.ordersRepo.count({ where: { status: OrderStatus.AwaitingCaptain } }),
      this.ordersRepo.count({
        where: {
          status: In([
            OrderStatus.CaptainAssigned,
            OrderStatus.EnRoutePickup,
            OrderStatus.ArrivedPickup,
            OrderStatus.PickedUp,
            OrderStatus.EnRouteDelivery,
            OrderStatus.ArrivedDropoff,
          ]),
        },
      }),
      this.ordersRepo.count({
        where: {
          status: In([
            OrderStatus.Delivered,
            OrderStatus.Completed,
          ]),
        },
      }),
      this.ordersRepo.count(),
      this.captainsRepo.count({ where: { verificationStatus: VerificationStatus.Pending } }),
      this.subsRepo.count({ where: { status: PaymentStatus.UnderReview } }),
      this.paymentsRepo.count({ where: { status: PaymentStatus.UnderReview } }),
      this.subsRepo
        .createQueryBuilder('s')
        .select('COALESCE(SUM(s.amount),0)', 'sum')
        .where('s.status = :st', { st: PaymentStatus.Approved })
        .getRawOne<{ sum: string }>(),
    ]);

    return {
      usersCount,
      captainsCount,
      customersCount,
      ordersCount: awaitingCaptainCount,
      activeOrdersCount,
      deliveredCount,
      totalOrdersCount,
      pendingVerification,
      pendingSubscriptions,
      pendingPayments,
      subscriptionRevenue: Number(revenue?.sum ?? 0),
      serviceFeeRevenue: Number(
        (
          await this.paymentsRepo
            .createQueryBuilder('p')
            .select('COALESCE(SUM(p.amount),0)', 'sum')
            .where('p.status = :st', { st: PaymentStatus.Approved })
            .getRawOne<{ sum: string }>()
        )?.sum ?? 0,
      ),
    };
  }

  async listCaptains(status?: VerificationStatus) {
    const qb = this.captainsRepo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.user', 'user')
      .orderBy('c.createdAt', 'DESC');
    if (status) qb.where('c.verificationStatus = :status', { status });
    return qb.getMany();
  }

  async captainDetail(captainProfileId: string) {
    const profile = await this.captainsRepo.findOne({
      where: { id: captainProfileId },
      relations: { user: true },
    });
    if (!profile) throw new NotFoundException('Captain profile not found');
    const subscriptions = await this.subsRepo.find({
      where: { captainId: profile.userId },
      order: { createdAt: 'DESC' },
    });
    const delivered = await this.ordersRepo.count({
      where: { captainId: profile.userId, status: OrderStatus.Completed },
    });
    return { ...profile, subscriptions, deliveredCount: delivered };
  }

  async reviewCaptainVerification(userId: string, adminId: string, dto: ReviewCaptainVerificationDto) {
    const profile = await this.captainsRepo.findOne({ where: { userId }, relations: { user: true } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    if (dto.action === 'approve') {
      profile.verificationStatus = VerificationStatus.Approved;
      profile.verificationNote = dto.note ?? null;
    } else {
      profile.verificationStatus = VerificationStatus.Rejected;
      profile.verificationNote = dto.note ?? null;
    }
    await this.captainsRepo.save(profile);
    await this.notifications.push(
      [userId],
      dto.action === 'approve' ? 'captain:verified' : 'captain:verification_rejected',
      dto.action === 'approve' ? 'تم توثيق حسابك ✅' : 'تم رفض التوثيق',
      dto.note ??
        (dto.action === 'approve'
          ? 'تم التحقق من وثائقك بنجاح. يمكنك الآن تفعيل الاشتراك واستقبال الطلبات.'
          : 'يرجى إعادة إرسال الوثائق الصحيحة.'),
      { captainProfileId: profile.id },
    );
    return profile;
  }

  async toggleCaptainActive(userId: string) {
    const profile = await this.captainsRepo.findOne({ where: { userId } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    profile.isActive = !profile.isActive;
    if (!profile.isActive) profile.isAvailable = false;
    await this.captainsRepo.save(profile);
    await this.notifications.push(
      [userId],
      profile.isActive ? 'captain:activated' : 'captain:deactivated',
      profile.isActive ? 'تم تفعيل حسابك ✅' : 'تم إيقاف حسابك',
      profile.isActive
        ? 'تم تفعيل حسابك من قبل الإدارة، يمكنك الآن استقبال الطلبات.'
        : 'تم إيقاف حسابك مؤقتاً من قبل الإدارة.',
    );
    return profile;
  }

  async listUsers(role?: UserRole) {
    const qb = this.usersRepo.createQueryBuilder('u').orderBy('u.createdAt', 'DESC');
    if (role) qb.where('u.role = :role', { role });
    return qb.getMany();
  }

  async toggleBan(userId: string) {
    const user = await this.usersRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    user.isBanned = !user.isBanned;
    if (user.isBanned) user.fcmToken = null;
    await this.usersRepo.save(user);
    await this.notifications.push(
      [userId],
      user.isBanned ? 'account:banned' : 'account:unbanned',
      user.isBanned ? 'تم إيقاف حسابك' : 'تم إعادة تفعيل حسابك',
      user.isBanned
        ? 'تم إيقاف حسابك مؤقتاً من قبل الإدارة.'
        : 'تم إعادة تفعيل حسابك، أهلاً بعودتك.',
    );
    return user;
  }

  async listReviews() {
    return this.reviewsRepo.find({
      relations: { reviewer: true, reviewee: true, order: true },
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  async listPayments() {
    return this.paymentsRepo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.order', 'order')
      .leftJoinAndSelect('p.reviewedBy', 'reviewedBy')
      .leftJoinAndSelect('order.customer', 'customer')
      .orderBy('p.createdAt', 'DESC')
      .getMany();
  }

  async listOrders(status?: string) {
    const qb = this.ordersRepo
      .createQueryBuilder('o')
      .leftJoinAndSelect('o.customer', 'customer')
      .leftJoinAndSelect('o.captain', 'captain')
      .leftJoinAndSelect('o.payments', 'payments')
      .orderBy('o.createdAt', 'DESC');
    if (status) qb.where('o.status = :status', { status });
    return qb.getMany();
  }

  async hideReview(reviewId: string) {
    const review = await this.reviewsRepo.findOne({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');
    review.isHidden = !review.isHidden;
    await this.reviewsRepo.save(review);
    return review;
  }
}