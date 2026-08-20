# Twsil API Reference

Base URL: `http://localhost:4000/api` · Auth: `Authorization: Bearer <jwt>`

## Enums

- **UserRole**: `customer` `captain` `admin`
- **OrderStatus**: `payment_pending` `awaiting_captain` `captain_assigned` `en_route_pickup` `arrived_pickup` `picked_up` `en_route_delivery` `arrived_dropoff` `delivered` `completed` `cancelled` `reassign`
- **PaymentStatus**: `awaiting_payment` `payment_submitted` `approved` `rejected` `remitted`
- **SubscriptionStatus**: `active` `expired` `inactive` `cancelled` `under_review` `rejected`
- **VerificationStatus**: `unsubmitted` `submitted` `verification_pending` `verification_approved` `verification_rejected`
- **PaymentMethod**: `jawwal_pay` `bank_transfer` `pal_pay`

## Auth

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/auth/register` | `{phone, password, firstName, lastName, email?}` | customer; returns `{accessToken, user}` |
| POST | `/auth/register/captain` | `{phone, password, firstName, lastName, email?, transportType, plateNumber, nationalId}` | returns same |
| POST | `/auth/login` | `{phone, password}` | |
| GET | `/auth/me` | | current user (with `captainProfile`) |
| PATCH | `/auth/profile` | `{firstName?, lastName?, email?, avatarUrl?, locale?}` | |

## Uploads

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/upload/image` | multipart `file` | returns `{url}`; images served from `/uploads/...` |

## Captain

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/captains/me` | | own `CaptainProfile` + user |
| PATCH | `/captains/me` | `{isAvailable?}` | toggles availability |
| POST | `/captains/verification` | `{docType: 'national_id'\|'driving_license', docImageUrl, licenseImageUrl?}` | rejects if already approved |
| GET | `/captains/available` | `?lat=&lng=` | deliverable available orders |
| POST | `/captains/subscriptions` | `{paymentMethod, receiptImageUrl, transactionNumber?, duration: 'monthly'\|'yearly'}` | submits (or renews) subscription |
| GET | `/captains/subscriptions` | | own subscription history |

## Orders

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/orders` | `{pickupAddress, pickupLat, pickupLng, dropoffAddress, dropoffLat, dropoffLng, description, packageType?='parcel'\|'food'\|'document'\|'other', paymentMethod, receiverName?, receiverPhone?, customerNote?}` | computes `deliveryFee` (5 + 2×km) + `serviceFee` (1) = `totalAmount` |
| GET | `/orders/mine` | | as customer: own orders; as captain: costs + delivering + history |
| GET | `/orders/available` | `?lat=&lng=` | open orders (awaiting_captain, payment approved) |
| GET | `/orders/:id` | | detail with payments, timeline, captain, reviews |
| POST | `/orders/:id/payments` | `{paymentMethod, receiptImageUrl, transactionNumber?}` | submit receipt → `payment_submitted` |
| POST | `/orders/:id/accept` | `{deliveryPriceEta?}` | captain accepts → `captain_assigned` |
| POST | `/orders/:id/transition` | `{action, pickupCode?}` | action: `start-pickup` `arrive-pickup` `picked-up` `start-delivery` `arrive-dropoff`; `picked-up` requires captain's 4-digit `pickupCode` |
| POST | `/orders/:id/delivered` | `{code}` | customer confirms with pickup code → `delivered` |
| POST | `/orders/:id/location` | `{lat, lng}` | captain updates live position (also via socket) |
| POST | `/orders/:id/rate` | `{rating 1-5, comment?}` | reviewee = captain |
| POST | `/orders/:id/cancel` | `{reason}` | customer cancels (rejected after `awaiting_captain`) |
| GET | `/orders/admin/list` | `?status=` | all orders + customer + captain + payments |
| GET | `/orders/admin/payments` | `?status=` | all order payments + order + customer |
| POST | `/orders/admin/payments/:paymentId/review` | `{action: 'approve'\|'reject'\|'request_receipt', note?}` | approve → order `awaiting_captain`; reject/request → `awaiting_payment` |

## Subscriptions (admin)

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/admin/subscriptions` | | all subscriptions + captain |
| POST | `/admin/subscriptions/:id/review` | `{action: 'approve'\|'reject'\|'request_receipt', note?}` | approve sets profile `subscriptionStatus: active` + `subscriptionExpiresAt` (+30 days) |

## Chat

| Method | Path | Notes |
|---|---|---|
| GET | `/chats/conversations` | inbox + unread counts |
| GET | `/chats/unread-count` | `{count}` |
| GET | `/chats/order/:orderId` | conversation for an order (creates customer↔captain) |
| POST | `/chats/:conversationId/messages` | `{content, type?='text'\|'image', attachmentUrl?}` |
| PATCH | `/chats/:conversationId/read` | mark read |
| POST | `/chats/admin-help` | admin help conversation with system admin |

## Notifications

| Method | Path | Notes |
|---|---|---|
| GET | `/notifications` | own, newest first |
| PATCH | `/notifications/read-all` | mark all read |

## Complaints

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/complaints` | `{message, orderId?}` | |
| GET | `/complaints/mine` | | own complaints |
| GET | `/complaints/admin/list` | | admin only |
| PATCH | `/complaints/admin/:id` | `{action: 'resolve', adminNote?}` | admin only |

## Admin

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/admin/stats` | | counts + revenues |
| GET | `/admin/captains` | `?status=` | profiles + user |
| GET | `/admin/captains/:id` | | profile detail + subscriptions + stats |
| POST | `/admin/captains/:userId/verification` | `{action: 'approve'\|'reject'\|'remove', note?}` | |
| GET | `/admin/users` | `?role=` | all users |
| POST | `/admin/users/:id/toggle-ban` | | |
| GET | `/admin/reviews` | | all reviews + author + order |
| POST | `/admin/reviews/:id/toggle-hide` | | |

## Socket.io (`/`)

- **Emit**: `tracking:update` `{orderId, lat, lng}`, `order:join` `{orderId}`, `chat:join` `{conversationId}`, `chat:typing`
- **Receive**: `order:status`, `tracking:update`, `order:taken`, `notification`, `chat:message`, `chat:read`, `chat:conversation`, `chat:typing`, `chat:admin-help` (authentication via socket handshake `auth.token`)