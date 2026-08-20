import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  PaymentMethod,
  PaymentStatus,
  Subscription,
} from '../database/entities/subscription.entity';
import { CaptainProfile, SubscriptionStatus } from '../database/entities/captain-profile.entity';
import { UserRole } from '../database/entities/user.entity';
import { User } from '../database/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';

export class SubmitSubscriptionDto {
  paymentMethod: PaymentMethod;
  receiptImageUrl: string;
  transactionNumber?: string;
  transferDate?: string;
  note?: string;
}

export class ReviewSubscriptionDto {
  action: 'approve' | 'reject' | 'request_receipt';
  note?: string;
}

export const SUBSCRIPTION_FEE = Number(process.env.SUBSCRIPTION_FEE ?? 10);
export const SUBSCRIPTION_DAYS = 30;

@Injectable()
export class SubscriptionsService {
  constructor(
    @InjectRepository(Subscription)
    private readonly subsRepo: Repository<Subscription>,
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    private readonly notifications: NotificationsService,
  ) {}

  async submit(captainId: string, dto: SubmitSubscriptionDto) {
    const profile = await this.captainsRepo.findOne({ where: { userId: captainId } });
    if (!profile) throw new NotFoundException('Captain profile not found');
    if (!dto.receiptImageUrl) throw new BadRequestException('Payment receipt image is required');
    if (!dto.paymentMethod) throw new BadRequestException('Payment method is required');

    let sub = await this.subsRepo.findOne({
      where: { captainId, status: PaymentStatus.Rejected },
      order: { createdAt: 'DESC' },
    });
    if (!sub) {
      sub = await this.subsRepo.findOne({
        where: { captainId, status: PaymentStatus.AwaitingPayment },
        order: { createdAt: 'DESC' },
      });
    }

    if (!sub) {
      sub = this.subsRepo.create({ captainId, amount: SUBSCRIPTION_FEE });
    } else {
      sub.amount = SUBSCRIPTION_FEE;
      sub.adminNote = null;
      sub.reviewedBy = null;
      sub.reviewedAt = null;
    }

    sub.paymentMethod = dto.paymentMethod;
    sub.receiptImageUrl = dto.receiptImageUrl;
    sub.transactionNumber = dto.transactionNumber ?? null;
    sub.transferDate = dto.transferDate ? new Date(dto.transferDate) : null;
    sub.note = dto.note ?? null;
    sub.status = PaymentStatus.UnderReview;

    await this.subsRepo.save(sub);
    await this.captainsRepo.update(profile.id, { subscriptionStatus: SubscriptionStatus.UnderReview });

    await this.notifyAdmins(
      'subscription:submitted',
      'اشتراك جديد قيد المراجعة',
      `سائق ينتظر مراجعة إيصال الاشتراك (رقم المعاملة: ${dto.transactionNumber ?? '—'})`,
      { subscriptionId: sub.id },
    );
    await this.notifications.push(
      [captainId],
      'subscription:submitted',
      'تم استلام طلبك',
      'تم استلام إيصال الاشتراك وهو الآن قيد المراجعة من قبل الإدارة.',
    );

    return this.detail(sub.id);
  }

  async review(subId: string, reviewerId: string, dto: ReviewSubscriptionDto) {
    const sub = await this.subsRepo.findOne({
      where: { id: subId },
      relations: { captain: true, reviewedBy: true },
    });
    if (!sub) throw new NotFoundException('Subscription not found');
    const profile = await this.captainsRepo.findOne({ where: { userId: sub.captainId } });

    const reviewed = {
      adminNote: dto.note ?? null,
      reviewedById: reviewerId,
      reviewedAt: new Date(),
    };

    switch (dto.action) {
      case 'approve':
        Object.assign(sub, { ...reviewed, status: PaymentStatus.Approved });
        await this.subsRepo.save(sub);
        if (profile) {
          await this.captainsRepo.update(profile.id, {
            subscriptionStatus: SubscriptionStatus.Active,
            subscriptionExpiresAt: this.addDays(new Date(), SUBSCRIPTION_DAYS),
          });
        }
        await this.notifications.push(
          [sub.captainId],
          'subscription:approved',
          'تم تفعيل اشتراكك 🎉',
          'تمت الموافقة على اشتراكك. يمكنك الآن استقبال الطلبات.',
          { subscriptionId: sub.id },
        );
        break;
      case 'reject':
        Object.assign(sub, { ...reviewed, status: PaymentStatus.Rejected });
        await this.subsRepo.save(sub);
        if (profile) {
          await this.captainsRepo.update(profile.id, {
            subscriptionStatus: SubscriptionStatus.Rejected,
          });
        }
        await this.notifications.push(
          [sub.captainId],
          'subscription:rejected',
          'تم رفض الاشتراك',
          dto.note ?? 'لم يتم التحقق من إيصال الدفع. يرجى إعادة المحاولة.',
          { subscriptionId: sub.id },
        );
        break;
      case 'request_receipt':
        Object.assign(sub, { ...reviewed, status: PaymentStatus.AwaitingPayment });
        await this.subsRepo.save(sub);
        await this.notifications.push(
          [sub.captainId],
          'subscription:receipt_required',
          'يُطلب إيصال جديد',
          dto.note ?? 'يرجى رفع إيصال دفع جديد وواضح.',
          { subscriptionId: sub.id },
        );
        break;
      default:
        throw new BadRequestException('Invalid review action');
    }

    return this.detail(sub.id);
  }

  async listAll(status?: PaymentStatus) {
    const qb = this.subsRepo
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.captain', 'captain')
      .leftJoinAndSelect('captain.captainProfile', 'profile')
      .orderBy('s.createdAt', 'DESC');
    if (status) qb.where('s.status = :status', { status });
    return qb.getMany();
  }

  async historyForCaptain(captainId: string) {
    return this.subsRepo.find({
      where: { captainId },
      order: { createdAt: 'DESC' },
    });
  }

  async detail(id: string) {
    return this.subsRepo.findOne({
      where: { id },
      relations: { captain: true, reviewedBy: true },
    });
  }

  private async notifyAdmins(type: string, title: string, body: string, data: Record<string, unknown>) {
    const admins = await this.usersRepo.find({ where: { role: UserRole.Admin } });
    await this.notifications.push(
      admins.map((a) => a.id),
      type,
      title,
      body,
      data,
    );
  }

  private addDays(date: Date, days: number): Date {
    const copy = new Date(date);
    copy.setDate(copy.getDate() + days);
    return copy;
  }
}