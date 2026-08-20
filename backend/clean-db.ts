import 'dotenv/config';
import { DataSource } from 'typeorm';
import { User } from './src/database/entities/user.entity';
import { CaptainProfile } from './src/database/entities/captain-profile.entity';
import { Order } from './src/database/entities/order.entity';
import { OrderPayment } from './src/database/entities/order-payment.entity';
import { OrderTimeline } from './src/database/entities/order-timeline.entity';
import { CaptainOffer } from './src/database/entities/captain-offer.entity';
import { Conversation } from './src/database/entities/conversation.entity';
import { Message } from './src/database/entities/message.entity';
import { Notification } from './src/database/entities/notification.entity';
import { Review } from './src/database/entities/review.entity';
import { Complaint } from './src/database/entities/complaint.entity';
import { Subscription } from './src/database/entities/subscription.entity';

const isPostgres = process.env.DATABASE_TYPE === 'postgres';

const dataSource = new DataSource({
  type: isPostgres ? 'postgres' : 'better-sqlite3',
  database: isPostgres ? process.env.DB_NAME : 'twsil.db',
  host: process.env.DB_HOST,
  port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
  username: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  entities: [User, CaptainProfile, Order, OrderPayment, OrderTimeline, CaptainOffer, Conversation, Message, Notification, Review, Complaint, Subscription],
  synchronize: false,
} as any);

async function cleanDatabase() {
  await dataSource.initialize();
  console.log('Connected to database');

  // Disable foreign key checks for SQLite
  if (!isPostgres) {
    await dataSource.query('PRAGMA foreign_keys = OFF');
  }

  try {
    // Order matters: delete children first, then parents
    await dataSource.query('DELETE FROM messages');
    await dataSource.query('DELETE FROM conversations');

    await dataSource.query('DELETE FROM order_payments');
    await dataSource.query('DELETE FROM order_timeline');
    await dataSource.query('DELETE FROM captain_offers');
    await dataSource.query('DELETE FROM orders');

    await dataSource.query('DELETE FROM subscriptions');

    await dataSource.query('DELETE FROM reviews');
    await dataSource.query('DELETE FROM complaints');
    await dataSource.query('DELETE FROM notifications');

    await dataSource.query('DELETE FROM captain_profiles');

    await dataSource.query('DELETE FROM users');

    // Reset SQLite sequences if using SQLite
    if (!isPostgres) {
      const tables = [
        'users',
        'captain_profiles',
        'orders',
        'order_payments',
        'order_timeline',
        'captain_offers',
        'conversations',
        'messages',
        'notifications',
        'reviews',
        'complaints',
        'subscriptions',
      ];
      for (const table of tables) {
        try {
          await dataSource.query(`DELETE FROM sqlite_sequence WHERE name = ?`, [table]);
        } catch (_) {
          // sqlite_sequence may not exist if no AUTOINCREMENT columns
        }
      }
      await dataSource.query('PRAGMA foreign_keys = ON');
    }

    console.log('Database cleaned successfully - all data removed, schema preserved');
  } catch (err) {
    console.error('Error cleaning database:', err);
    throw err;
  } finally {
    await dataSource.destroy();
  }
}

cleanDatabase().catch((e) => {
  console.error(e);
  process.exit(1);
});