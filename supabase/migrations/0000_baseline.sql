-- ============================================================
-- Twsil baseline: schema as previously created by TypeORM
-- Captured from live Supabase project (ymqtrsnikcicywxtfjsx)
-- ============================================================

create extension if not exists "uuid-ossp";

create type public.users_role_enum as enum ('customer', 'captain', 'admin');
create type public.orders_packagesize_enum as enum ('small', 'medium', 'large');
create type public.orders_status_enum as enum ('payment_pending', 'awaiting_captain', 'captain_assigned', 'en_route_pickup', 'arrived_pickup', 'picked_up', 'en_route_delivery', 'arrived_dropoff', 'delivered', 'completed', 'cancelled');
create type public.order_payments_paymentmethod_enum as enum ('jawwal_pay', 'bop_palestine', 'palpay');
create type public.order_payments_status_enum as enum ('awaiting_payment', 'payment_submitted', 'under_review', 'approved', 'rejected');
create type public.subscriptions_paymentmethod_enum as enum ('jawwal_pay', 'bop_palestine', 'palpay');
create type public.subscriptions_status_enum as enum ('awaiting_payment', 'payment_submitted', 'under_review', 'approved', 'rejected');
create type public.captain_profiles_transporttype_enum as enum ('car', 'motorcycle', 'bicycle', 'other');
create type public.captain_profiles_verificationstatus_enum as enum ('pending', 'approved', 'rejected');
create type public.captain_profiles_subscriptionstatus_enum as enum ('inactive', 'submitted', 'under_review', 'active', 'rejected');
create type public.complaints_status_enum as enum ('open', 'in_progress', 'resolved', 'rejected');
create type public.messages_type_enum as enum ('text', 'image', 'system');

create table public.users (
  id uuid not null default uuid_generate_v4(),
  "firstName" character varying not null,
  "lastName" character varying not null,
  phone character varying not null,
  email text,
  "passwordHash" character varying not null default '',
  role public.users_role_enum not null default 'customer'::public.users_role_enum,
  "avatarUrl" text,
  locale character varying not null default 'ar'::character varying,
  "isPhoneVerified" boolean not null default false,
  "fcmToken" text,
  "isBanned" boolean not null default false,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_a3ffb1c0c8416b9fc6f907b7433" primary key (id)
);
alter table public.users owner to postgres;
create unique index "UQ_a000cca60bcf04454e727699490" on public.users (phone);
create index "IDX_a000cca60bcf04454e72769949" on public.users (role);
create index "IDX_d6ebeb00b543ceb3267d2f42ca" on public.users ("isBanned");

create table public.captain_profiles (
  id uuid not null default uuid_generate_v4(),
  "userId" uuid not null,
  "transportType" public.captain_profiles_transporttype_enum not null,
  "plateNumber" text,
  "nationalId" text,
  city text,
  bio text,
  "verificationStatus" public.captain_profiles_verificationstatus_enum not null default 'pending'::public.captain_profiles_verificationstatus_enum,
  "verificationNote" text,
  "idCardVerified" boolean not null default false,
  "licenseVerified" boolean not null default false,
  "subscriptionStatus" public.captain_profiles_subscriptionstatus_enum not null default 'inactive'::public.captain_profiles_subscriptionstatus_enum,
  "subscriptionExpiresAt" timestamp without time zone,
  "isAvailable" boolean not null default false,
  rating double precision not null default '0'::double precision,
  "ratingCount" integer not null default 0,
  "totalDeliveries" integer not null default 0,
  "totalEarnings" double precision not null default '0'::double precision,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_54c3192beae8e7e2f7831ab8781" primary key (id),
  constraint "REL_a2a0f6a468cd4fac819f7993d3" unique ("userId")
);
alter table public.captain_profiles owner to postgres;
alter table public.captain_profiles add constraint "FK_a2a0f6a468cd4fac819f7993d3" foreign key ("userId") references public.users(id) on delete cascade;

create table public.orders (
  id uuid not null default uuid_generate_v4(),
  "orderNumber" character varying not null,
  "customerId" uuid not null,
  "captainId" uuid,
  "pickupLat" double precision not null,
  "pickupLng" double precision not null,
  "pickupAddress" character varying not null,
  "dropoffLat" double precision not null,
  "dropoffLng" double precision not null,
  "dropoffAddress" character varying not null,
  "packageDescription" text not null,
  "packageSize" public.orders_packagesize_enum not null default 'medium'::public.orders_packagesize_enum,
  "weightKg" double precision not null default '0'::double precision,
  "distanceKm" double precision not null default '0'::double precision,
  "deliveryFee" double precision,
  "serviceFee" double precision,
  status public.orders_status_enum not null default 'payment_pending'::public.orders_status_enum,
  "cancellationReason" text,
  "cancelledByUserId" text,
  "currentLat" double precision,
  "currentLng" double precision,
  "lastTrackingAt" timestamp without time zone,
  "pickupCode" character varying,
  "ratedByCustomer" boolean not null default false,
  "ratedByCaptain" boolean not null default false,
  "deliveredConfirmedByCustomer" boolean not null default false,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_710e2d4957aa5878dfe94e4ac2f" primary key (id)
);
alter table public.orders owner to postgres;
alter table public.orders add constraint "UQ_59b0c3b34ea0fa5562342f24143" unique ("orderNumber");
alter table public.orders add constraint "FK_e5de51ca888d8b1f5ac25799dd" foreign key ("captainId") references public.users(id) on delete set null;
alter table public.orders add constraint "FK_775c9f06fc27ae3ff8fb26f2c4" foreign key ("customerId") references public.users(id) on delete cascade;
create index "IDX_d6ebeb00b543ceb3267d2f42ca" on public.orders ("captainId");
create index "IDX_775c9f06fc27ae3ff8fb26f2c4" on public.orders ("customerId");

create table public.order_payments (
  id uuid not null default uuid_generate_v4(),
  "orderId" uuid not null,
  amount double precision not null,
  "paymentMethod" public.order_payments_paymentmethod_enum not null,
  "receiptImageUrl" text,
  "transactionNumber" text,
  "transferDate" timestamp without time zone,
  note text,
  status public.order_payments_status_enum not null default 'awaiting_payment'::public.order_payments_status_enum,
  "adminNote" text,
  "reviewedById" uuid,
  "reviewedAt" timestamp without time zone,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_bc14b014a69d39c7bbc4a154b69" primary key (id)
);
alter table public.order_payments owner to postgres;
alter table public.order_payments add constraint "FK_abca480893311e20150f01b2f1" foreign key ("reviewedById") references public.users(id) on delete set null;
alter table public.order_payments add constraint "FK_b0a057dbf38cec095c3113622a" foreign key ("orderId") references public.orders(id) on delete cascade;
create index "IDX_abca480893311e20150f01b2f1" on public.order_payments ("reviewedById");
create index "IDX_b0a057dbf38cec095c3113622a" on public.order_payments ("orderId");

create table public.subscriptions (
  id uuid not null default uuid_generate_v4(),
  "captainId" uuid not null,
  amount double precision not null,
  "paymentMethod" public.subscriptions_paymentmethod_enum not null,
  "receiptImageUrl" text,
  "transactionNumber" text,
  "transferDate" timestamp without time zone,
  note text,
  status public.subscriptions_status_enum not null default 'awaiting_payment'::public.subscriptions_status_enum,
  "adminNote" text,
  "reviewedById" uuid,
  "reviewedAt" timestamp without time zone,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_a87248d73155605cf782be9ee5e" primary key (id)
);
alter table public.subscriptions owner to postgres;
alter table public.subscriptions add constraint "FK_6ccf973355b70645eff37774de" foreign key ("reviewedById") references public.users(id) on delete set null;
alter table public.subscriptions add constraint "FK_14f6200196a977ee997451b0b4" foreign key ("captainId") references public.users(id) on delete cascade;
create index "IDX_6ccf973355b70645eff37774de" on public.subscriptions ("reviewedById");
create index "IDX_14f6200196a977ee997451b0b4" on public.subscriptions ("captainId");

create table public.complaints (
  id uuid not null default uuid_generate_v4(),
  "reporterId" uuid not null,
  "againstUserId" uuid,
  "orderId" uuid,
  subject character varying not null,
  description text not null,
  "resolutionNote" text,
  status public.complaints_status_enum not null default 'open'::public.complaints_status_enum,
  "resolvedById" uuid,
  "resolvedAt" timestamp without time zone,
  "createdAt" timestamp without time zone not null default now(),
  "updatedAt" timestamp without time zone not null default now(),
  constraint "PK_4b7566a2a489c2cc7c12ed076ad" primary key (id)
);
alter table public.complaints owner to postgres;
alter table public.complaints add constraint "FK_208ad761b4359509cd2f43da87" foreign key ("againstUserId") references public.users(id) on delete set null;
alter table public.complaints add constraint "FK_40cbdbb1a0c58560068efddb80" foreign key ("orderId") references public.orders(id) on delete set null;
alter table public.complaints add constraint "FK_4b7566a2a489c2cc7c12ed076ad" foreign key ("reporterId") references public.users(id) on delete cascade;
create index "IDX_208ad761b4359509cd2f43da87" on public.complaints ("againstUserId");
create index "IDX_40cbdbb1a0c58560068efddb80" on public.complaints ("orderId");

create table public.reviews (
  id uuid not null default uuid_generate_v4(),
  "orderId" uuid not null,
  "reviewerId" uuid not null,
  "revieweeId" uuid not null,
  rating integer not null,
  comment text,
  "isHidden" boolean not null default false,
  "createdAt" timestamp without time zone not null default now(),
  constraint "PK_231ae565c273ee700b283f15c1d" primary key (id)
);
alter table public.reviews owner to postgres;
alter table public.reviews add constraint "UQ_8fd613871076f3c1794cbcd6099" unique ("orderId", "reviewerId");
alter table public.reviews add constraint "FK_53a68dc905777554b7f702791f" foreign key ("revieweeId") references public.users(id);
alter table public.reviews add constraint "FK_c8f626e1e943aabb0f90fb8ee6" foreign key ("reviewerId") references public.users(id);
alter table public.reviews add constraint "FK_231ae565c273ee700b283f15c1d" foreign key ("orderId") references public.orders(id) on delete cascade;
create index "IDX_c8f626e1e943aabb0f90fb8ee6" on public.reviews ("reviewerId");
create index "IDX_53a68dc905777554b7f702791f" on public.reviews ("revieweeId");

create table public.conversations (
  id uuid not null default uuid_generate_v4(),
  "orderId" uuid not null,
  "customerId" uuid not null,
  "captainId" uuid,
  "createdAt" timestamp without time zone not null default now(),
  constraint "PK_ee34f4f7ced4ec8681f26bf04ef" primary key (id)
);
alter table public.conversations owner to postgres;
alter table public.conversations add constraint "REL_1fc3133b966bb83dc957188b71" unique ("orderId");
alter table public.conversations add constraint "FK_1fc3133b966bb83dc957188b71" foreign key ("orderId") references public.orders(id) on delete cascade;
alter table public.conversations add constraint "FK_ee34f4f7ced4ec8681f26bf04ef" foreign key ("customerId") references public.users(id) on delete cascade;
alter table public.conversations add constraint "FK_2c4bd9ba0b8b8c2c3a1d4e5f6a" foreign key ("captainId") references public.users(id) on delete set null;

create table public.messages (
  id uuid not null default uuid_generate_v4(),
  "conversationId" uuid not null,
  "senderId" uuid not null,
  type public.messages_type_enum not null default 'text'::public.messages_type_enum,
  body text not null,
  "imageUrl" text,
  "isRead" boolean not null default false,
  "readAt" timestamp without time zone,
  "createdAt" timestamp without time zone not null default now(),
  constraint "PK_18325f38ae6de43878487eff986" primary key (id)
);
alter table public.messages owner to postgres;
alter table public.messages add constraint "FK_e5663ce0c730b2de83445e2fd1" foreign key ("conversationId") references public.conversations(id) on delete cascade;
alter table public.messages add constraint "FK_0153f2869f814003ded5901f08a" foreign key ("senderId") references public.users(id) on delete cascade;
create index "IDX_e5663ce0c730b2de83445e2fd1" on public.messages ("conversationId");

create table public.notifications (
  id uuid not null default uuid_generate_v4(),
  "userId" uuid not null,
  type character varying not null,
  title character varying not null,
  body text not null,
  data text,
  "isRead" boolean not null default false,
  "readAt" timestamp without time zone,
  "createdAt" timestamp without time zone not null default now(),
  constraint "PK_6a72c3c0f683f6462415e653c3a" primary key (id)
);
alter table public.notifications owner to postgres;
alter table public.notifications add constraint "FK_692a909ee0fa9383e7859f9b40" foreign key ("userId") references public.users(id) on delete cascade;
create index "IDX_692a909ee0fa9383e7859f9b40" on public.notifications ("userId");

create table public.order_timeline (
  id uuid not null default uuid_generate_v4(),
  "orderId" uuid not null,
  event text not null,
  note text,
  "actorId" uuid,
  "createdAt" timestamp without time zone not null default now(),
  constraint "PK_e6c8ff4a57760022bbf838d2a73" primary key (id)
);
alter table public.order_timeline owner to postgres;
alter table public.order_timeline add constraint "FK_a5f8f6552d9fef14d5d19497cd" foreign key ("orderId") references public.orders(id) on delete cascade;
alter table public.order_timeline add constraint "FK_7875a65e9c5f6a3a4f66b0d6c1f" foreign key ("actorId") references public.users(id) on delete set null;