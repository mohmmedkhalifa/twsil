import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';

export interface FcmMessage {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private app: any; // firebase-admin App (lazy init)
  private messaging: any; // Messaging instance

  constructor(
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
  ) {}

  get enabled(): boolean {
    return Boolean(
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
    );
  }

  private init() {
    if (this.messaging || !this.enabled) return;
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin');
      const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      const serviceAccount = raw
        ? JSON.parse(raw)
        : require(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH!));
      const credential = admin.cert ?? admin.credential?.cert;
      if (!credential) throw new Error('firebase-admin credential helper not found');
      if (admin.getApps().length === 0) {
        this.app = admin.initializeApp({
          credential: credential(serviceAccount),
        });
      } else {
        this.app = admin.getApps()[0];
      }
      // firebase-admin v14: messaging is a subpath export.
      const messagingModule = require('firebase-admin/messaging');
      const getMessaging = messagingModule.getMessaging ?? messagingModule.default?.getMessaging;
      if (!getMessaging) throw new Error('firebase-admin/messaging not found');
      this.messaging = getMessaging(this.app);
    } catch (e) {
      this.logger.warn(`FCM disabled: ${(e as Error).message}`);
      this.logger.warn(`FCM debug stack: ${(e as Error).stack}`);
      this.messaging = null;
    }
  }

  async tokensFor(userIds: string[]): Promise<string[]> {
    if (userIds.length === 0) return [];
    const users = await this.usersRepo.find({
      where: userIds.map((id) => ({ id })),
      select: { fcmToken: true },
    });
    return users.map((u) => u.fcmToken).filter((t): t is string => Boolean(t));
  }

  async sendToUserIds(
    userIds: string[],
    title: string,
    body: string,
    data?: Record<string, string | number | boolean>,
  ) {
    this.init();
    if (!this.messaging) return;
    const tokens = await this.tokensFor(userIds);
    if (tokens.length === 0) return;
    const payload: FcmMessage = {
      tokens,
      title,
      body,
      data: data ? (Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) as Record<string, string>) : undefined,
    };
    try {
      const result = await this.messaging.sendEachForMulticast({
        tokens: payload.tokens,
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      this.logger.log(
        `FCM sent: ${result.successCount} OK / ${result.failureCount} failed`,
      );
    } catch (e) {
      this.logger.warn(`FCM send failed: ${(e as Error).message}`);
    }
  }
}