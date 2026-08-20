import 'dotenv/config';
import 'reflect-metadata';
import { DataSource, DataSourceOptions } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserRole } from './entities/user.entity';
import { CaptainProfile, SubscriptionStatus, TransportType, VerificationStatus } from './entities/captain-profile.entity';
import { entities } from './entities.index';

async function seed() {
  const isPostgres = process.env.DATABASE_TYPE === 'postgres';
  const options: DataSourceOptions = isPostgres
    ? {
        type: 'postgres',
        host: process.env.DB_HOST ?? 'localhost',
        port: Number(process.env.DB_PORT ?? 5432),
        username: process.env.DB_USERNAME,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME ?? 'twsil',
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
        entities,
        synchronize: true,
      }
    : {
        type: 'better-sqlite3',
        database: 'twsil.db',
        entities,
        synchronize: true,
      };

  const dataSource = new DataSource(options);
  await dataSource.initialize();

  const usersRepo = dataSource.getRepository(User);
  const captainsRepo = dataSource.getRepository(CaptainProfile);

  const adminPhone = process.env.ADMIN_PHONE ?? '0599999999';
  const adminPassword = process.env.ADMIN_PASSWORD ?? 'Admin@12345';

  const demo = [
    {
      phone: adminPhone,
      password: adminPassword,
      firstName: 'مدير',
      lastName: 'النظام',
      role: UserRole.Admin,
      locale: 'ar',
    },
    {
      phone: process.env.DEMO_CUSTOMER_PHONE ?? '0599000111',
      password: process.env.DEMO_CUSTOMER_PASSWORD ?? 'Customer@12345',
      firstName: 'أحمد',
      lastName: 'العميل',
      role: UserRole.Customer,
      locale: 'ar',
    },
    {
      phone: process.env.DEMO_CAPTAIN_PHONE ?? '0599000222',
      password: process.env.DEMO_CAPTAIN_PASSWORD ?? 'Captain@12345',
      firstName: 'خالد',
      lastName: 'الكابتن',
      role: UserRole.Captain,
      locale: 'ar',
    },
  ];

  for (const d of demo) {
    let user = await usersRepo.findOne({ where: { phone: d.phone } });
    if (!user) {
      user = await usersRepo.save(
        usersRepo.create({
          firstName: d.firstName,
          lastName: d.lastName,
          phone: d.phone,
          passwordHash: await bcrypt.hash(d.password, 10),
          role: d.role,
          locale: d.locale,
          isPhoneVerified: true,
        }),
      );
      console.log(`Created ${d.role}: ${d.phone} / ${d.password}`);
    } else {
      console.log(`${d.role} already exists: ${d.phone}`);
    }

    if (d.role === UserRole.Captain) {
      let profile = await captainsRepo.findOne({ where: { userId: user.id } });
      if (!profile) {
        profile = captainsRepo.create({
          userId: user.id,
          transportType: TransportType.Car,
          plateNumber: '6-1234-99',
          nationalId: '29205100100456',
          city: 'غزة',
          bio: 'سائق توصيل معتمد، جاهز لخدمتك.',
          verificationStatus: VerificationStatus.Approved,
          subscriptionStatus: SubscriptionStatus.Active,
          subscriptionExpiresAt: new Date(Date.now() + 30 * 24 * 3600 * 1000),
          isAvailable: true,
          isActive: true,
          rating: 5,
          ratingCount: 1,
          lastLat: 31.5017,
          lastLng: 34.4668,
        });
        await captainsRepo.save(profile);
        console.log(`Created captain profile: ${d.phone}`);
      }
    }
  }

  await dataSource.destroy();
  console.log('Seed completed.');
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});