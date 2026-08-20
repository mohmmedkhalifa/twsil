# Twsil | توصيل

Decentralized delivery platform for Palestine — customer app, captain (driver) app, and admin dashboard.

> Single source of truth: the **NestJS backend owns the database, realtime events and push notifications**.
> Mobile and admin never talk to Supabase directly.

- **mobile/**: Flutter app (Android + iOS) — customers order, captains deliver, real-time chat & tracking, manual payment via receipt (Jawwal Pay / Bank of Palestine / PalPay)
- **admin/**: Flutter Web admin dashboard — payment center, captain verification, subscriptions, orders, complaints, users, reviews (polls the backend every 10s)
- **backend/**: NestJS + TypeORM + Socket.io API — SQLite in dev, PostgreSQL supported
- **docs/**: (planned) API reference & deployment guide

## Features

- OTP-free phone/password auth with roles: `customer`, `captain`, `admin`
- Captain subscription: 10 ILS / month via receipt upload, approved by admin
- Orders with live map tracking (OpenStreetMap, no API keys), 4-digit pickup code, distance-based fee (5 ILS base + 2 ILS/km + 1 ILS service fee)
- Real-time chat between customer & captain, admin help channel
- Notifications, complaints, ratings, admin ban/unban

## Running

### Backend

```bash
cd backend
npm install
cp .env.example .env
npm run seed        # creates admin: 0599999999 / Admin@12345
npm run start:dev   # or: npm run build && npm run start:prod
```

API: `http://localhost:4000/api`

### Mobile

```bash
cd mobile
flutter pub get
flutter run   # Android emulator uses http://10.0.2.2:4000 by default
```

Override the API URL: `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000/api`

### Admin

```bash
cd admin
flutter pub get
flutter run -d chrome --dart-define=ADMIN_API_URL=http://localhost:4000/api
flutter build web   # deploy build/web
```

Login with the seeded admin account (`0599999999 / Admin@12345`).

## Architecture

```
mobile/               Flutter customer + captain app
  lib/core/           config, theme, models, dio client, socket client
  lib/features/       auth, orders, captain, notifications, profile, customer, shell
admin/                Flutter Web admin dashboard
  lib/core/           light dio client + theme
  lib/screens/        stats, payment center, orders, captains, users, complaints, reviews
backend/              NestJS monolith
  src/auth/           JWT auth
  src/orders/         orders, payments, timeline, chat, reviews
  src/captains/       profiles, verification, availability
  src/subscriptions/  captain subscriptions (admin review)
  src/chat/           conversations + messages
  src/notifications/  in-app notifications
  src/complaints/     complaints
  src/admin/          stats, users, captains, reviews
  src/realtime/       Socket.io gateway (order tracking, chat)
  src/uploads/        receipt image uploads (multer)
```

## Payment flow (manual)

1. Customer/captain pays via Jawwal Pay / Bank of Palestine / PalPay
2. Uploads the receipt image in the app
3. Admin reviews it in the **Payment Center** → approve, reject (with note), or request a clearer receipt
4. On approval the order progresses / subscription activates

## Tech notes

- `flutter_map` + OpenStreetMap: free, no API keys, works offline-friendly in Palestine
- SQLite (`better-sqlite3`) for zero-config dev; set `DATABASE_TYPE=postgres` in `.env` for production
- Uploads stored in `backend/uploads/` (signed URLs planned)
- Receipt approval decrements customer balance credits the admin-side totals; subscription revenue + service fee totals shown on the dashboard

## Repo layout todo

- [ ] docs/API.md
- [ ] docs/schema.md
- [ ] LICENSE# twsil
