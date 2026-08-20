import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from '../database/entities/notification.entity';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { FcmService } from '../fcm/fcm.service';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationsRepo: Repository<Notification>,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
  ) {}

  async push(
    userIds: string[],
    type: string,
    title: string,
    body: string,
    data?: Record<string, unknown>,
  ) {
    const unique = [...new Set(userIds.filter(Boolean))];
    if (unique.length === 0) return;

    const entities = unique.map((userId) =>
      this.notificationsRepo.create({
        userId,
        type,
        title,
        body,
        data: data ? JSON.stringify(data) : null,
      }),
    );
    const saved = await this.notificationsRepo.save(entities);

    for (const notif of saved) {
      this.realtime.sendToUser(notif.userId, 'notification', {
        id: notif.id,
        type,
        title,
        body,
        data,
        isRead: false,
        createdAt: notif.createdAt,
      });
    }

    await this.fcm.sendToUserIds(unique, title, body, data as Record<string, string | number | boolean>);
  }

  async list(userId: string) {
    return this.notificationsRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async markRead(userId: string, id: string) {
    await this.notificationsRepo.update({ id, userId }, { isRead: true, readAt: new Date() });
    return { ok: true };
  }

  async unreadCount(userId: string) {
    return this.notificationsRepo.count({ where: { userId, isRead: false } });
  }
}