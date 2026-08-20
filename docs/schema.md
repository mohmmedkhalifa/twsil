# Database Schema

SQLite in dev (`backend/twsil.db`), PostgreSQL in prod (`DATABASE_TYPE=postgres` in `.env`).
Migrations are auto-sync (`synchronize: true`) via TypeORM — safe until first production deploy.

## users

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| phone | text UNIQUE | login identifier |
| passwordHash | text | bcrypt |
| firstName / lastName | text | |
| email | text NULL | |
| role | enum `customer` `captain` `admin` | |
| avatarUrl | text NULL | |
| locale | text default `ar` | |
| isPhoneVerified | boolean default false | |
| fcmToken | text NULL | (push planned) |
| isBanned | boolean default false | banned users cannot log in/act |
| createdAt / updatedAt | datetime | |

## captain_profiles

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| userId | uuid FK→users | unique, one-to-one |
| transportType | enum `motorcycle` `car` `bicycle` `other` | |
| plateNumber | text | |
| nationalId | text | stored hashed in prod |
| docType | enum `national_id` `driving_license` | |
| docImageUrl / licenseImageUrl | text NULL | |
| verificationStatus | enum (see API doc) default `unsubmitted` | |
| verificationNote | text NULL | admin rejection reason |
| verificationReviewedBy | uuid FK→users NULL | |
| isAvailable | boolean default false | accepts orders |
| rating | float default 0 | avg of review ratings |
| ratingCount | int default 0 | |
| subscriptionStatus | enum default `inactive` | |
| subscriptionExpiresAt | datetime NULL | +30 days on approval |
| reviewedAt | datetime NULL | |

## subscriptions

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| captainId | uuid FK→users | |
| amount | int | `SUBSCRIPTION_FEE` (10) |
| paymentMethod | enum `jawwal_pay` `bank_transfer` `pal_pay` | |
| receiptImageUrl | text | |
| transactionNumber | text NULL | |
| duration | enum default `monthly` | |
| status | enum `awaiting_payment` `payment_submitted` `under_review` `approved` `rejected` | submitted → under_review |
| note | text NULL | captain note |
| adminNote | text NULL | |
| reviewedById / reviewedAt | uuid FK / datetime NULL | |
| startDate / endDate | datetime NULL | set on approval |

## orders

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| orderNumber | text unique | `TWYYYYMMDD-####` |
| customerId | uuid FK→users | |
| captainId | uuid FK→users NULL | |
| pickupAddress / dropoffAddress | text | |
| pickupLat / pickupLng / dropoffLat / dropoffLng | float | |
| description | text | |
| packageType | enum default `parcel` | |
| paymentMethod | enum | |
| receiverName / receiverPhone | text NULL | optional |
| customerNote | text NULL | |
| deliveryFee | int | 5 + 2×km (haversine) |
| serviceFee | int | `SERVICE_FEE` (1) |
| status | enum (see API doc) | |
| pickupCode | int NULL | 4 digits, shown at `awaiting_captain` |
| isDelivered | boolean | |
| cancelledReason | text NULL | |
| cancelledBy | enum `customer` `captain` `admin` NULL | |
| deliveredAt / cancelledAt | datetime NULL | |
| captainBid | int NULL | captain acceptance price override |
| acceptEta | text NULL | |

Indexes: `status`, `captainId`, `customerId`, created_at DESC.

## order_payments

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| orderId | uuid FK→orders | one order → one pending payment chain |
| amount | int | |
| method | enum | |
| receiptImageUrl | text | |
| transactionNumber | text NULL | |
| status | enum | submitted → paid: `approved`, else `awaiting_payment` (request clearer receipt) |
| adminNote | text NULL | |
| reviewedById / reviewedAt | uuid FK / datetime NULL | |
| submittedAt | datetime | |

## order_timeline

| column | type | notes |
|---|---|---|
| id | uuid PK | |
| orderId | uuid FK→orders | |
| actorId | uuid FK→users NULL | |
| actorRole | enum NULL | |
| event | text | e.g. `created` `payment:approved` `accept` `status:start-pickup` |
| message | text | localized display |
| lat / lng | float NULL | optional event location |

## conversations & messages

**conversations**: id, orderId FK NULL (null = admin help), customerId FK NULL, captainId FK NULL, custUnread/captainUnread int, lastMessageAt datetime, createdAt.

**messages**: id, conversationId FK, senderId FK→users, type enum `text` `image`, content text, attachmentUrl text NULL, readAt datetime NULL, createdAt.

## notifications

id, userId FK→users, type text, title text, body text, data text (JSON), isRead boolean, createdAt.

## complaints

id, reporterId FK→users, againstUserId FK NULL, orderId FK NULL, message text, status enum `open` `in_progress` `resolved` `reassign`, adminNote text NULL, handledById FK NULL, createdAt/updatedAt.

## reviews

id, orderId FK unique, authorId FK→users, revieweeId FK→users (captain), rating int 1-5, comment text NULL, isHidden boolean, createdAt.

## Fees (`.env`)

- `SUBSCRIPTION_FEE=10` ILS
- `SERVICE_FEE=1` ILS
- `BASE_DELIVERY_FEE=5` ILS
- `FEE_PER_KM=2` ILS/km
- `SUBSCRIPTION_DAYS=30`