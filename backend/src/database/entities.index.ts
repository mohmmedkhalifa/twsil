import { User } from './entities/user.entity';
import { CaptainProfile } from './entities/captain-profile.entity';
import { CaptainOffer } from './entities/captain-offer.entity';
import { Subscription } from './entities/subscription.entity';
import { Order } from './entities/order.entity';
import { OrderPayment } from './entities/order-payment.entity';
import { OrderTimeline } from './entities/order-timeline.entity';
import { Conversation } from './entities/conversation.entity';
import { Message } from './entities/message.entity';
import { Notification } from './entities/notification.entity';
import { Complaint } from './entities/complaint.entity';
import { Review } from './entities/review.entity';

export const entities = [
  User,
  CaptainProfile,
  CaptainOffer,
  Subscription,
  Order,
  OrderPayment,
  OrderTimeline,
  Conversation,
  Message,
  Notification,
  Complaint,
  Review,
];