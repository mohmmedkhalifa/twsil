import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Conversation } from '../database/entities/conversation.entity';
import { Message, MessageType } from '../database/entities/message.entity';
import { Order } from '../database/entities/order.entity';
import { User, UserRole } from '../database/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

export class SendMessageDto {
  body: string;
  type?: MessageType;
  imageUrl?: string;
}

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Conversation)
    private readonly conversationsRepo: Repository<Conversation>,
    @InjectRepository(Message)
    private readonly messagesRepo: Repository<Message>,
    @InjectRepository(Order)
    private readonly ordersRepo: Repository<Order>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async ensureConversation(orderId: string): Promise<Conversation> {
    let conversation = await this.conversationsRepo.findOne({ where: { orderId } });
    if (!conversation) {
      const order = await this.ordersRepo.findOne({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');
      conversation = this.conversationsRepo.create({
        orderId,
        customerId: order.customerId,
        captainId: order.captainId,
      });
      conversation = await this.conversationsRepo.save(conversation);
    }
    return conversation;
  }

  async conversationForUser(orderId: string, userId: string) {
    let conversation = await this.conversationsRepo.findOne({
      where: { orderId },
      relations: { customer: true, captain: true, messages: { sender: true } },
    });
    if (!conversation || conversation.captainId === null) {
      const order = await this.ordersRepo.findOne({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Conversation not found');
      let offerId: string | null = null;
      if (order.captainId) {
        const withOffer = await this.conversationsRepo.findOne({
          where: { orderId, captainId: order.captainId },
        });
        offerId = withOffer?.offerId ?? null;
      }
      if (!conversation) {
        conversation = this.conversationsRepo.create({
          orderId,
          customerId: order.customerId,
          captainId: order.captainId,
          offerId,
        });
        conversation = await this.conversationsRepo.save(conversation);
      } else {
        conversation.captainId = order.captainId;
        conversation.offerId = offerId ?? conversation.offerId;
        conversation = await this.conversationsRepo.save(conversation);
      }
    }
    this.assertMember(conversation, userId);
    return this.conversationsRepo.findOne({
      where: { id: conversation.id },
      relations: { customer: true, captain: true, messages: { sender: true } },
    });
  }

  async getConversation(userId: string, orderId: string) {
    const conversation = await this.conversationsRepo.findOne({
      where: { orderId },
      relations: { customer: true, captain: true, messages: { sender: true } },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    this.assertMember(conversation, userId);
    return conversation;
  }

  async messagesForUser(userId: string, conversationId: string) {
    const conversation = await this.conversationsRepo.findOne({
      where: { id: conversationId },
      relations: { customer: true, captain: true },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    this.assertMember(conversation, userId);
    return this.messagesRepo.find({
      where: { conversationId },
      relations: { sender: true },
      order: { createdAt: 'ASC' },
    });
  }

  async send(userId: string, conversationId: string, dto: SendMessageDto) {
    if (!dto.body && !dto.imageUrl) throw new BadRequestException('Message body or image is required');
    const conversation = await this.conversationsRepo.findOne({
      where: { id: conversationId },
      relations: { order: true, customer: true, captain: true },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    this.assertMember(conversation, userId);

    const message = this.messagesRepo.create({
      conversationId,
      senderId: userId,
      type: dto.type && dto.imageUrl ? MessageType.Image : MessageType.Text,
      body: dto.imageUrl ? '' : dto.body,
      imageUrl: dto.imageUrl ?? null,
    });
    const saved = await this.messagesRepo.save(message);

    if (!conversation.captainId && dto.body) {
      const admins = await this.usersRepo.find({ where: { role: UserRole.Admin } });
      admins.forEach((admin) =>
        this.realtime.sendToUser(admin.id, 'chat:admin-help', {
          conversationId: conversation.id,
          orderId: conversation.orderId,
          message: dto.body.slice(0, 100),
        }),
      );
    }

    const receiverId =
      conversation.customerId === userId ? conversation.captainId : conversation.customerId;
    const payload = {
      id: saved.id,
      conversationId,
      senderId: userId,
      type: saved.type,
      body: saved.body,
      imageUrl: saved.imageUrl,
      createdAt: saved.createdAt,
    };
    this.realtime.sendToConversation(conversationId, 'chat:message', payload);

    if (receiverId) {
      this.realtime.sendToUser(receiverId, 'chat:conversation', {
        conversationId,
        orderId: conversation.orderId,
        orderNumber: conversation.order?.orderNumber,
      });
      await this.notifications.push(
        [receiverId],
        'chat:message',
        'رسالة جديدة',
        saved.type === MessageType.Image ? 'أُرسلت صورة' : saved.body.slice(0, 100),
        { conversationId, orderId: conversation.orderId },
      );
    }
    return saved;
  }

  async markRead(userId: string, conversationId: string) {
    const conversation = await this.conversationsRepo.findOne({
      where: { id: conversationId },
      relations: { messages: true },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    this.assertMember(conversation, userId);
    const unread = conversation.messages.filter(
      (m) => m.senderId !== userId && !m.isRead,
    );
    if (unread.length > 0) {
      await this.messagesRepo.update(
        unread.map((m) => m.id),
        { isRead: true, readAt: new Date() },
      );
      this.realtime.sendToConversation(conversationId, 'chat:read', {
        conversationId,
        userId,
      });
    }
    return { ok: true };
  }

  async conversations(userId: string) {
    const convos = await this.conversationsRepo.find({
      where: [{ customerId: userId }, { captainId: userId }],
      relations: {
        order: { customer: true, captain: true },
        messages: { sender: true },
      },
      order: { createdAt: 'DESC' },
    });
    return convos.map((c) => {
      const last = c.messages.length > 0 ? c.messages[c.messages.length - 1] : null;
      const other = c.customerId === userId ? c.captain : c.customer;
      return {
        id: c.id,
        orderId: c.orderId,
        orderNumber: c.order?.orderNumber,
        otherUser: other
          ? { id: other.id, firstName: other.firstName, lastName: other.lastName, avatarUrl: other.avatarUrl }
          : null,
        customerId: c.customerId,
        captainId: c.captainId,
        lastMessage: last
          ? { body: last.body, type: last.type, createdAt: last.createdAt, senderId: last.senderId }
          : null,
        createdAt: c.createdAt,
      };
    });
  }

  async unreadCount(userId: string): Promise<number> {
    return this.messagesRepo
      .createQueryBuilder('m')
      .innerJoin('m.conversation', 'c')
      .where('(c.customerId = :userId OR c.captainId = :userId)', { userId })
      .andWhere('m.senderId != :userId', { userId })
      .andWhere('m.isRead = false')
      .getCount();
  }

  private assertMember(conversation: Conversation, userId: string) {
    if (conversation.customerId !== userId && conversation.captainId !== userId) {
      throw new ForbiddenException('Not a member of this conversation');
    }
  }
}