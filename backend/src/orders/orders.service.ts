import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  Order,
  OrderStatus,
  PackageSize,
} from '../database/entities/order.entity';
import {
  OrderPayment,
} from '../database/entities/order-payment.entity';
import { OrderTimeline } from '../database/entities/order-timeline.entity';
import { CaptainProfile, SubscriptionStatus, VerificationStatus } from '../database/entities/captain-profile.entity';
import { User, UserRole } from '../database/entities/user.entity';
import { Conversation } from '../database/entities/conversation.entity';
import { Review } from '../database/entities/review.entity';
import { PaymentMethod, PaymentStatus } from '../database/entities/subscription.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { haversineKm } from '../common/utils/haversine';

export class CreateOrderDto {
  pickupLat: number;
  pickupLng: number;
  pickupAddress: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress: string;
  packageDescription: string;
  packageSize?: PackageSize;
  weightKg?: number;
}

export class SubmitOrderPaymentDto {
  paymentMethod: PaymentMethod;
  receiptImageUrl: string;
  transactionNumber?: string;
  transferDate?: string;
  note?: string;
}

export class ReviewOrderPaymentDto {
  action: 'approve' | 'reject' | 'request_receipt';
  note?: string;
}

export class CancelOrderDto {
  reason: string;
}

export class RateOrderDto {
  rating: number;
  comment?: string;
}

const BASE_DELIVERY_FEE = Number(process.env.BASE_DELIVERY_FEE ?? 5);
const FEE_PER_KM = Number(process.env.FEE_PER_KM ?? 2);
const SERVICE_FEE = Number(process.env.SERVICE_FEE ?? 1);

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private readonly ordersRepo: Repository<Order>,
    @InjectRepository(OrderPayment)
    private readonly paymentsRepo: Repository<OrderPayment>,
    @InjectRepository(OrderTimeline)
    private readonly timelineRepo: Repository<OrderTimeline>,
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    @InjectRepository(Conversation)
    private readonly conversationsRepo: Repository<Conversation>,
    @InjectRepository(Review)
    private readonly reviewsRepo: Repository<Review>,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async create(customerId: string, dto: CreateOrderDto) {
    this.assertLatLng(dto.pickupLat, dto.pickupLng, 'pickup');
    this.assertLatLng(dto.dropoffLat, dto.dropoffLng, 'dropoff');
    if (!dto.pickupAddress || !dto.dropoffAddress || !dto.packageDescription) {
      throw new BadRequestException('Pickup address, dropoff address and package description are required');
    }

    const distanceKm = Math.round(
      haversineKm(
        dto.pickupLat,
        dto.pickupLng,
        dto.dropoffLat,
        dto.dropoffLng,
      ) * 1000
    ) / 1000;
    const deliveryFee = 0;

    const order = this.ordersRepo.create({
      orderNumber: this.generateOrderNumber(),
      customerId,
      pickupLat: dto.pickupLat,
      pickupLng: dto.pickupLng,
      pickupAddress: dto.pickupAddress,
      dropoffLat: dto.dropoffLat,
      dropoffLng: dto.dropoffLng,
      dropoffAddress: dto.dropoffAddress,
      packageDescription: dto.packageDescription,
      packageSize: dto.packageSize ?? PackageSize.Medium,
      weightKg: dto.weightKg ?? 0,
      distanceKm: Math.round(distanceKm * 100) / 100,
      deliveryFee,
      serviceFee: SERVICE_FEE,
      status: OrderStatus.PaymentPending,
      pickupCode: String(Math.floor(1000 + Math.random() * 9000)),
    });
    const saved = await this.ordersRepo.save(order);

    await this.addTimeline(saved.id, customerId, 'order:created', 'تم إنشاء الطلب بانتظار الدفع');
    await this.notifications.push(
      [customerId],
      'order:created',
      'تم إنشاء الطلب',
      `الرجاء دفع رسوم الخدمة (${SERVICE_FEE} شيكل) وتأكيد الدفع لإتمام الطلب ${saved.orderNumber}.`,
      { orderId: saved.id },
    );
    return this.detail(saved.id, customerId);
  }

  async submitPayment(customerId: string, orderId: string, dto: SubmitOrderPaymentDto) {
    const order = await this.ordersRepo.findOne({
      where: { id: orderId, customerId },
      relations: { payments: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== OrderStatus.PaymentPending) {
      throw new BadRequestException('Order is not awaiting payment');
    }
    if (!dto.receiptImageUrl || !dto.paymentMethod) {
      throw new BadRequestException('Receipt image and payment method are required');
    }

    const existing = await this.paymentsRepo.findOne({
      where: { orderId, status: PaymentStatus.Rejected },
      order: { createdAt: 'DESC' },
    });
    const payment =
      existing ??
      this.paymentsRepo.create({ orderId, amount: SERVICE_FEE });

    payment.paymentMethod = dto.paymentMethod;
    payment.receiptImageUrl = dto.receiptImageUrl;
    payment.transactionNumber = dto.transactionNumber ?? null;
    payment.transferDate = dto.transferDate ? new Date(dto.transferDate) : null;
    payment.note = dto.note ?? null;
    payment.status = PaymentStatus.UnderReview;
    payment.adminNote = null;
    payment.reviewedById = null;
    payment.reviewedAt = null;
    await this.paymentsRepo.save(payment);

    await this.ordersRepo.update(order.id, { status: OrderStatus.PaymentPending });
    await this.addTimeline(order.id, customerId, 'payment:submitted', 'تم رفع إيصال الدفع للمراجعة');
    await this.notifyAdmins(
      'order:payment_submitted',
      'إيصال دفع جديد للمراجعة',
      `طلب ${order.orderNumber} بانتظار مراجعة إيصال خدمة الدفع.`,
      { orderId, paymentId: payment.id },
    );
    await this.notifications.push(
      [customerId],
      'order:payment_submitted',
      'إيصال الدفع قيد المراجعة',
      'تم استلام إيصالك، وسيتم تأكيد الطلب بعد موافقة الإدارة.',
      { orderId },
    );
    return this.detail(order.id, customerId);
  }

  async reviewOrderPayment(adminId: string, paymentId: string, dto: ReviewOrderPaymentDto) {
    const payment = await this.paymentsRepo.findOne({
      where: { id: paymentId },
      relations: { order: { customer: true } },
    });
    if (!payment) throw new NotFoundException('Payment not found');

    const reviewed: Partial<OrderPayment> = {
      adminNote: dto.note ?? null,
      reviewedById: adminId,
      reviewedAt: new Date(),
    };

    switch (dto.action) {
      case 'approve':
        payment.status = PaymentStatus.Approved;
        Object.assign(payment, reviewed);
        await this.paymentsRepo.save(payment);
        if (payment.order && payment.order.status === OrderStatus.PaymentPending) {
          await this.ordersRepo.update(payment.orderId, { status: OrderStatus.AwaitingCaptain });
          this.realtime.sendToCaptains('order:created', { orderId: payment.orderId });
        }
        await this.addTimeline(payment.orderId, adminId, 'payment:approved', 'تم الموافقة على الدفع');
        await this.notifications.push(
          [payment.order.customerId],
          'order:payment_approved',
          'تم تأكيد الدفع ✅',
          'تمت الموافقة على الدفع، طلبك أصبح متاحاً للسائقين الآن.',
          { orderId: payment.orderId },
        );
        break;
      case 'reject':
        payment.status = PaymentStatus.Rejected;
        Object.assign(payment, reviewed);
        await this.paymentsRepo.save(payment);
        await this.addTimeline(payment.orderId, adminId, 'payment:rejected', dto.note ?? '');
        await this.notifications.push(
          [payment.order.customerId],
          'order:payment_rejected',
          'تم رفض الدفع',
          dto.note ?? 'لم يتم التحقق من إيصال الدفع.',
          { orderId: payment.orderId },
        );
        break;
      case 'request_receipt':
        payment.status = PaymentStatus.AwaitingPayment;
        Object.assign(payment, reviewed);
        await this.paymentsRepo.save(payment);
        await this.notifications.push(
          [payment.order.customerId],
          'order:receipt_required',
          'يُطلب إيصال جديد',
          dto.note ?? 'يرجى رفع إيصال دفع جديد وواضح.',
          { orderId: payment.orderId },
        );
        break;
      default:
        throw new BadRequestException('Invalid review action');
    }
    return payment;
  }

  async availableOrders(captainId: string) {
    const profile = await this.captainsRepo.findOne({ where: { userId: captainId } });
    const isApproved = profile && (
      profile.verificationStatus === VerificationStatus.Approved ||
      (profile.verificationStatus as string) === 'verification_approved'
    );
    if (!profile || !isApproved || profile.isActive === false) {
      throw new ForbiddenException('حسابك غير مفعل أو بانتظار توثيق الإدارة');
    }
    return this.ordersRepo.find({
      where: { status: OrderStatus.AwaitingCaptain },
      relations: { customer: true, payments: true },
      order: { createdAt: 'ASC' },
      take: 50,
    });
  }

  async acceptOrder(captainId: string, orderId: string) {
    const profile = await this.captainsRepo.findOne({
      where: { userId: captainId },
      relations: { user: true },
    });
    if (!profile) throw new NotFoundException('Captain profile not found');
    const isApproved = profile.verificationStatus === VerificationStatus.Approved ||
                       (profile.verificationStatus as string) === 'verification_approved';
    if (!isApproved || profile.isActive === false) {
      throw new ForbiddenException('حسابك غير مفعل أو بانتظار توثيق الإدارة');
    }

    const order = await this.ordersRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    if (order.status !== OrderStatus.AwaitingCaptain) {
      throw new BadRequestException('Order is no longer available');
    }

    await this.ordersRepo.update(order.id, {
      captainId,
      status: OrderStatus.CaptainAssigned,
    });
    // Captain is now busy: hide him from the "available captains" list immediately.
    await this.captainsRepo.update(profile.id, { isAvailable: false });
    this.realtime.sendToCustomers('captain:availability_updated', {
      userId: captainId,
      isAvailable: false,
    });
    let conversation = await this.conversationsRepo.findOne({ where: { orderId: order.id } });
    if (!conversation) {
      conversation = this.conversationsRepo.create({
        orderId: order.id,
        customerId: order.customerId,
        captainId,
      });
      conversation = await this.conversationsRepo.save(conversation);
    }

    await this.addTimeline(order.id, captainId, 'order:assigned', 'تم قبول الطلب من قبل سائق');
    this.realtime.sendToCaptains('order:taken', { orderId: order.id });
    this.realtime.sendToOrder(order.id, 'order:status', {
      orderId: order.id,
      status: OrderStatus.CaptainAssigned,
    });
    await this.notifications.push(
      [order.customerId],
      'order:assigned',
      'تم العثور على سائق 🛵',
      'قام سائق بقبول طلبك وأصبح في طريقه إليك.',
      { orderId: order.id },
    );
    await this.notifications.push(
      [captainId],
      'order:accepted',
      'تم قبول الطلب',
      `طلب ${order.orderNumber} أصبح لديك الآن.`,
      { orderId: order.id },
    );
    return this.detail(order.id, captainId);
  }

  async transition(captainId: string, orderId: string, action: string, code?: string) {
    const order = await this.ordersRepo.findOne({ where: { id: orderId, captainId } });
    if (!order) throw new NotFoundException('Order not found or not assigned to you');
    const map: Record<string, { from: OrderStatus[]; to: OrderStatus; event: string; note: string }> = {
      'start-pickup': {
        from: [OrderStatus.CaptainAssigned],
        to: OrderStatus.EnRoutePickup,
        event: 'order:en_route_pickup',
        note: 'السائق في طريقه إلى نقطة الاستلام',
      },
      'arrive-pickup': {
        from: [OrderStatus.EnRoutePickup],
        to: OrderStatus.ArrivedPickup,
        event: 'order:arrived_pickup',
        note: 'وصل السائق إلى نقطة الاستلام',
      },
      'picked-up': {
        from: [OrderStatus.ArrivedPickup],
        to: OrderStatus.PickedUp,
        event: 'order:picked_up',
        note: 'تم استلام الطرد من المرسل',
      },
      'start-delivery': {
        from: [OrderStatus.PickedUp],
        to: OrderStatus.EnRouteDelivery,
        event: 'order:en_route_delivery',
        note: 'السائق في طريقه إلى التسليم',
      },
      'arrive-dropoff': {
        from: [OrderStatus.EnRouteDelivery],
        to: OrderStatus.ArrivedDropoff,
        event: 'order:arrived_dropoff',
        note: 'وصل السائق إلى وجهة التسليم',
      },
    };

    const step = map[action];
    if (!step) throw new BadRequestException('Invalid action');
    if (!step.from.includes(order.status)) {
      throw new BadRequestException(`Cannot ${action} from status ${order.status}`);
    }
    if (action === 'picked-up' && code && code !== order.pickupCode) {
      throw new BadRequestException('Invalid pickup code');
    }

    await this.ordersRepo.update(order.id, { status: step.to });
    await this.addTimeline(order.id, captainId, step.event, step.note);
    this.realtime.sendToOrder(order.id, 'order:status', {
      orderId: order.id,
      status: step.to,
      note: step.note,
    });
    await this.notifications.push(
      [order.customerId],
      'order:status',
      'تحديث حالة الطلب',
      step.note,
      { orderId: order.id, status: step.to },
    );
    return this.detail(order.id, captainId);
  }

  async markDelivered(orderId: string, userId: string) {
    const order = await this.ordersRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    const isCustomer = order.customerId === userId;
    const isCaptain = order.captainId === userId;
    if (!isCustomer && !isCaptain) throw new ForbiddenException('Not allowed');

    if (isCustomer && !order.deliveredConfirmedByCustomer) {
      await this.ordersRepo.update(order.id, { deliveredConfirmedByCustomer: true });
    }
    if (order.status === OrderStatus.ArrivedDropoff) {
      await this.ordersRepo.update(order.id, { status: OrderStatus.Delivered });
      await this.addTimeline(order.id, userId, 'order:delivered', 'تم تسليم الطلب');
      this.realtime.sendToOrder(order.id, 'order:status', {
        orderId,
        status: OrderStatus.Delivered,
      });
      const captainProfile = order.captainId
        ? await this.captainsRepo.findOne({ where: { userId: order.captainId } })
        : null;
      if (captainProfile) {
        await this.captainsRepo.update(captainProfile.id, {
          totalDeliveries: (captainProfile.totalDeliveries ?? 0) + 1,
          totalEarnings: (captainProfile.totalEarnings ?? 0) + (order.deliveryFee ?? 0),
          isAvailable: true,
        });
        this.realtime.sendToCustomers('captain:availability_updated', {
          userId: order.captainId,
          isAvailable: true,
        });
      }
      const targets = [order.customerId, order.captainId].filter((x): x is string => Boolean(x));
      await this.notifications.push(targets, 'order:delivered', 'تم تسليم الطلب 🎉', 'اكتمل تسليم الطلب بنجاح.', { orderId });
    }
    return this.detail(order.id, userId);
  }

  async rate(userId: string, orderId: string, dto: RateOrderDto) {
    if (dto.rating < 1 || dto.rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5');
    }
    const order = await this.ordersRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    const role = userId === order.customerId ? 'customer' : userId === order.captainId ? 'captain' : null;
    if (!role) throw new ForbiddenException('Not allowed');
    if (order.status !== OrderStatus.Delivered) {
      throw new BadRequestException('Order must be delivered to rate');
    }

    const revieweeId =
      role === 'customer' && order.captainId
        ? order.captainId
        : role === 'captain'
          ? order.customerId
          : null;
    if (!revieweeId) throw new BadRequestException('Cannot rate without a counterpart');
    const existing = await this.reviewsRepo.findOne({ where: { orderId, reviewerId: userId } });
    const review =
      existing ??
      this.reviewsRepo.create({ orderId, reviewerId: userId, revieweeId, rating: dto.rating, comment: dto.comment });

    if (existing) {
      review.rating = dto.rating;
      review.comment = dto.comment ?? null;
    }
    await this.reviewsRepo.save(review);

    if (role === 'customer') {
      await this.ordersRepo.update(order.id, { ratedByCustomer: true });
      await this.recalcCaptainRating(revieweeId);
    } else {
      await this.ordersRepo.update(order.id, { ratedByCaptain: true });
    }
    return review;
  }

  async cancel(customerId: string, orderId: string, dto: CancelOrderDto) {
    const order = await this.ordersRepo.findOne({ where: { id: orderId, customerId } });
    if (!order) throw new NotFoundException('Order not found');
    if (![OrderStatus.PaymentPending, OrderStatus.AwaitingCaptain].includes(order.status)) {
      throw new BadRequestException('Order cannot be cancelled at this stage');
    }
    await this.ordersRepo.update(order.id, {
      status: OrderStatus.Cancelled,
      cancellationReason: dto.reason,
      cancelledByUserId: customerId,
    });
    await this.addTimeline(order.id, customerId, 'order:cancelled', dto.reason);
    this.realtime.sendToOrder(order.id, 'order:status', { orderId, status: OrderStatus.Cancelled });
    await this.notifications.push(
      [customerId],
      'order:cancelled',
      'تم إلغاء الطلب',
      'تم إلغاء طلبك بنجاح.',
      { orderId },
    );
    return this.detail(order.id, customerId);
  }

  async updateLocation(captainId: string, orderId: string, lat: number, lng: number) {
    const order = await this.ordersRepo.findOne({ where: { id: orderId, captainId } });
    if (!order) throw new NotFoundException('Order not found or not assigned to you');
    await this.ordersRepo.update(order.id, {
      currentLat: lat,
      currentLng: lng,
      lastTrackingAt: new Date(),
    });
    this.realtime.sendToOrder(order.id, 'tracking:update', {
      orderId,
      lat,
      lng,
      at: new Date().toISOString(),
    });
    return { ok: true };
  }

  async detail(orderId: string, viewerId: string) {
    const order = await this.ordersRepo.findOne({
      where: { id: orderId },
      relations: {
        customer: true,
        captain: true,
        payments: true,
        timeline: true,
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    const isParty = order.customerId === viewerId || order.captainId === viewerId;
    const viewer = await this.usersRepo.findOne({
      where: { id: viewerId },
      select: { id: true, role: true },
    });
    if (!isParty && viewer?.role !== UserRole.Admin) throw new ForbiddenException('Not allowed');
    const conversation = await this.conversationsRepo.findOne({ where: { orderId } });
    return { ...order, conversationId: conversation?.id ?? null };
  }

  async myOrders(userId: string, role: UserRole) {
    const where = role === UserRole.Captain ? { captainId: userId } : { customerId: userId };
    return this.ordersRepo.find({
      where,
      relations: { customer: true, captain: true, payments: true },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async listAll(status?: OrderStatus) {
    const qb = this.ordersRepo
      .createQueryBuilder('o')
      .leftJoinAndSelect('o.customer', 'customer')
      .leftJoinAndSelect('o.captain', 'captain')
      .leftJoinAndSelect('o.payments', 'payments')
      .orderBy('o.createdAt', 'DESC');
    if (status) qb.where('o.status = :status', { status });
    return qb.getMany();
  }

  async listOrderPayments(status?: PaymentStatus) {
    const qb = this.paymentsRepo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.order', 'order')
      .leftJoinAndSelect('order.customer', 'customer')
      .orderBy('p.createdAt', 'DESC');
    if (status) qb.where('p.status = :status', { status });
    return qb.getMany();
  }

  private async recalcCaptainRating(revieweeId: string) {
    const profile = await this.captainsRepo.findOne({ where: { userId: revieweeId } });
    if (!profile) return;
    const { avg, count } = await this.reviewsRepo
      .createQueryBuilder('r')
      .select('AVG(r.rating)', 'avg')
      .addSelect('COUNT(r.id)', 'count')
      .where('r.revieweeId = :id', { id: revieweeId })
      .getRawOne();
    await this.captainsRepo.update(profile.id, {
      rating: Math.round(Number(avg ?? 0) * 10) / 10,
      ratingCount: Number(count ?? 0),
    });
  }

  private async addTimeline(orderId: string, actorId: string, event: string, note: string) {
    await this.timelineRepo.save(this.timelineRepo.create({ orderId, actorId, event, note }));
  }

  private async notifyAdmins(type: string, title: string, body: string, data: Record<string, unknown>) {
    const admins = await this.usersRepo.find({ where: { role: UserRole.Admin } });
    await this.notifications.push(admins.map((a) => a.id), type, title, body, data);
  }

  private assertLatLng(lat: number, lng: number, field: string) {
    if (typeof lat !== 'number' || typeof lng !== 'number' || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new BadRequestException(`Valid ${field} coordinates are required`);
    }
  }

  private roundFee(value: number): number {
    return Math.round(value * 2) / 2;
  }

  private generateOrderNumber(): string {
    const now = new Date();
    const date = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
    const random = Math.floor(1000 + Math.random() * 9000);
    return `TW${date}-${random}`;
  }
}