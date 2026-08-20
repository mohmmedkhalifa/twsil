import { BadRequestException, Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { CaptainOffer, OfferStatus } from '../database/entities/captain-offer.entity';
import { Order, OrderStatus } from '../database/entities/order.entity';
import { Conversation } from '../database/entities/conversation.entity';
import { CaptainProfile, VerificationStatus } from '../database/entities/captain-profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

export class CreateOfferDto {
  price: number;
  estimatedTimeMinutes?: number;
  message?: string;
}

export class DirectRequestDto {
  captainId: string;
  itemDescription: string;
  pickupAddress: string;
  pickupLat?: number;
  pickupLng?: number;
  deliveryAddress: string;
  deliveryLat?: number;
  deliveryLng?: number;
  offeredPrice: number;
  deliveryNotes?: string;
}

@Injectable()
export class OffersService {
  constructor(
    @InjectRepository(CaptainOffer)
    private readonly offersRepo: Repository<CaptainOffer>,
    @InjectRepository(Order)
    private readonly ordersRepo: Repository<Order>,
    @InjectRepository(Conversation)
    private readonly conversationsRepo: Repository<Conversation>,
    @InjectRepository(CaptainProfile)
    private readonly captainsRepo: Repository<CaptainProfile>,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
    private readonly dataSource: DataSource,
  ) {}

  async createOrUpdateOffer(captainId: string, orderId: string, dto: CreateOfferDto) {
    const captainProfile = await this.captainsRepo.findOne({ where: { userId: captainId } });
    if (
      !captainProfile ||
      !captainProfile.isActive ||
      captainProfile.verificationStatus !== VerificationStatus.Approved
    ) {
      throw new ForbiddenException('حساب الكابتن غير مفعل أو لم يتم التحقق منه بعد');
    }

    const order = await this.ordersRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('الطلب غير موجود');
    if (order.status !== OrderStatus.AwaitingCaptain) {
      throw new BadRequestException('الطلب لم يعد متاحاً لتقديم العروض');
    }

    let offer = await this.offersRepo.findOne({ where: { orderId, captainId } });
    if (offer) {
      offer.price = dto.price;
      offer.estimatedTimeMinutes = dto.estimatedTimeMinutes ?? 30;
      offer.message = dto.message ?? null;
      offer.status = OfferStatus.Pending;
      await this.offersRepo.save(offer);
    } else {
      offer = this.offersRepo.create({
        orderId,
        captainId,
        price: dto.price,
        estimatedTimeMinutes: dto.estimatedTimeMinutes ?? 30,
        message: dto.message ?? null,
        status: OfferStatus.Pending,
      });
      await this.offersRepo.save(offer);
    }

    let conversation = await this.conversationsRepo.findOne({ where: { orderId, captainId } });
    if (!conversation) {
      conversation = this.conversationsRepo.create({
        orderId,
        customerId: order.customerId,
        captainId,
        offerId: offer.id,
      });
      await this.conversationsRepo.save(conversation);
    } else if (!conversation.offerId) {
      conversation.offerId = offer.id;
      await this.conversationsRepo.save(conversation);
    }

    this.realtime.sendToUser(order.customerId, 'offer:created', {
      orderId,
      offerId: offer.id,
      captainId,
      price: offer.price,
      estimatedTimeMinutes: offer.estimatedTimeMinutes,
      message: offer.message,
      conversationId: conversation.id,
    });
    this.realtime.sendToOrder(orderId, 'offer:created', { offerId: offer.id });

    await this.notifications.push(
      [order.customerId],
      'offer:new',
      'عرض توصيل جديد',
      `قدم الكابتن عرض بقيمة ${offer.price} ₪ لتوصيل طلبك`,
      { orderId, offerId: offer.id, conversationId: conversation.id },
    );

    return { ...offer, conversationId: conversation.id };
  }

  async getOrderOffers(userId: string, orderId: string) {
    const order = await this.ordersRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('الطلب غير موجود');

    const offers = await this.offersRepo.find({
      where: { orderId },
      relations: { captain: true },
      order: { createdAt: 'DESC' },
    });

    const conversations = await this.conversationsRepo.find({
      where: { orderId },
    });
    const convMap = new Map(conversations.map((c) => [c.captainId, c.id]));

    const captainProfiles = await this.captainsRepo.find();
    const profileMap = new Map(captainProfiles.map((p) => [p.userId, p]));

    return offers.map((offer) => {
      const profile = profileMap.get(offer.captainId);
      return {
        ...offer,
        conversationId: convMap.get(offer.captainId) ?? null,
        captain: offer.captain
          ? {
              id: offer.captain.id,
              firstName: offer.captain.firstName,
              lastName: offer.captain.lastName,
              avatarUrl: offer.captain.avatarUrl,
              rating: profile?.rating ?? 5.0,
              totalDeliveries: profile?.totalDeliveries ?? 0,
              transportType: profile?.transportType ?? 'car',
            }
          : undefined,
      };
    });
  }

  async acceptOffer(customerId: string, offerId: string) {
    return this.dataSource.transaction(async (manager) => {
      const offer = await manager.findOne(CaptainOffer, {
        where: { id: offerId },
        relations: { order: true, captain: true },
      });

      if (!offer) throw new NotFoundException('العرض غير موجود');
      if (offer.order.customerId !== customerId) {
        throw new ForbiddenException('ليس لديك صلاحية قبول هذا العرض');
      }
      if (offer.order.status !== OrderStatus.AwaitingCaptain) {
        throw new BadRequestException('الطلب لم يعد بانتظار سائق');
      }
      if (offer.status !== OfferStatus.Pending) {
        throw new BadRequestException('العرض غير متاح للقبول');
      }

      offer.order.status = OrderStatus.CaptainAssigned;
      offer.order.captainId = offer.captainId;
      offer.order.deliveryFee = offer.price;
      await manager.save(Order, offer.order);

      offer.status = OfferStatus.Accepted;
      await manager.save(CaptainOffer, offer);

      const captainProfile = await manager.findOne(CaptainProfile, {
        where: { userId: offer.captainId },
      });
      if (captainProfile) {
        await manager.update(CaptainProfile, captainProfile.id, { isAvailable: false });
      }
      this.realtime.sendToCustomers('captain:availability_updated', {
        userId: offer.captainId,
        isAvailable: false,
      });

      await manager
        .createQueryBuilder()
        .update(CaptainOffer)
        .set({ status: OfferStatus.Rejected })
        .where('orderId = :orderId AND id != :offerId AND status = :status', {
          orderId: offer.orderId,
          offerId: offer.id,
          status: OfferStatus.Pending,
        })
        .execute();

      const conversation = await manager.findOne(Conversation, {
        where: { orderId: offer.orderId, captainId: offer.captainId },
      });

      this.realtime.sendToUser(offer.captainId, 'offer:accepted', {
        orderId: offer.orderId,
        offerId: offer.id,
        conversationId: conversation?.id,
      });
      this.realtime.sendToOrder(offer.orderId, 'order:updated', {
        status: OrderStatus.CaptainAssigned,
        captainId: offer.captainId,
      });
      this.realtime.sendToCaptains('order:taken', { orderId: offer.orderId });

      await this.notifications.push(
        [offer.captainId],
        'offer:accepted',
        'تم قبول عرضك! 🎉',
        'وافق العميل على عرض التوصيل الخاص بك، يمكنك الآن الانطلاق لخدمة الطلب.',
        { orderId: offer.orderId, conversationId: conversation?.id },
      );

      return {
        message: 'تم قبول العرض بنجاح',
        order: offer.order,
        offer,
        conversationId: conversation?.id,
      };
    });
  }

  async rejectOffer(customerId: string, offerId: string) {
    const offer = await this.offersRepo.findOne({
      where: { id: offerId },
      relations: { order: true },
    });
    if (!offer) throw new NotFoundException('العرض غير موجود');
    if (offer.order.customerId !== customerId) {
      throw new ForbiddenException('ليس لديك صلاحية رفض هذا العرض');
    }

    offer.status = OfferStatus.Rejected;
    await this.offersRepo.save(offer);

    this.realtime.sendToUser(offer.captainId, 'offer:rejected', {
      orderId: offer.orderId,
      offerId: offer.id,
    });

    return { message: 'تم رفض العرض', offer };
  }

  async createDirectRequest(customerId: string, dto: DirectRequestDto) {
    const captainProfile = await this.captainsRepo.findOne({
      where: { userId: dto.captainId },
      relations: { user: true },
    });

    if (
      !captainProfile ||
      !captainProfile.isAvailable ||
      !captainProfile.isActive ||
      captainProfile.verificationStatus !== VerificationStatus.Approved
    ) {
      throw new BadRequestException('الكابتن غير متاح للطلب المباشر حالياً');
    }

    const orderNumber = `TWS-${Date.now().toString().slice(-6)}`;
    const order = this.ordersRepo.create({
      orderNumber,
      customerId,
      packageDescription: dto.itemDescription,
      pickupAddress: dto.pickupAddress,
      pickupLat: dto.pickupLat ?? 31.95,
      pickupLng: dto.pickupLng ?? 35.23,
      dropoffAddress: dto.deliveryAddress,
      dropoffLat: dto.deliveryLat ?? 31.96,
      dropoffLng: dto.deliveryLng ?? 35.24,
      deliveryFee: dto.offeredPrice,
      serviceFee: 1,
      status: OrderStatus.AwaitingCaptain,
    });
    await this.ordersRepo.save(order);

    const offer = this.offersRepo.create({
      orderId: order.id,
      captainId: dto.captainId,
      price: dto.offeredPrice,
      estimatedTimeMinutes: 30,
      message: 'طلب توصيل مباشر من العميل',
      status: OfferStatus.Pending,
      isDirectRequest: true,
    });
    await this.offersRepo.save(offer);

    const conversation = this.conversationsRepo.create({
      orderId: order.id,
      customerId,
      captainId: dto.captainId,
      offerId: offer.id,
    });
    await this.conversationsRepo.save(conversation);

    this.realtime.sendToUser(dto.captainId, 'direct_request:new', {
      orderId: order.id,
      offerId: offer.id,
      customerId,
      conversationId: conversation.id,
    });
    this.realtime.sendToCaptains('order:created', { orderId: order.id });

    await this.notifications.push(
      [dto.captainId],
      'direct_request:new',
      'طلب توصيل مباشر جديد 🚕',
      `أرسل لك عميل طلب توصيل مباشر بقيمة ${dto.offeredPrice} ₪`,
      { orderId: order.id, conversationId: conversation.id },
    );

    return {
      order,
      offer,
      conversationId: conversation.id,
    };
  }
}
