-- ============================================================
-- Migration 0005: Order creation robustness
--
-- 1. Idempotency: "clientRequestId" carries a client-generated token.
--    A UNIQUE index guarantees one user action maps to exactly ONE
--    order even across timeouts/retries/double taps. Multiple NULLs
--    are allowed (legacy rows and clients without tokens).
--
-- 2. Manual addresses: pickup/dropoff latitude & longitude become
--    optional so a valid textual address can exist without map
--    coordinates. No fake 0,0 placeholders are ever stored.
--
-- Idempotent and safe to re-run.
-- ============================================================

alter table public.orders add column if not exists "clientRequestId" text;

create unique index if not exists "UQ_orders_client_request_id"
  on public.orders ("clientRequestId");

alter table public.orders alter column "pickupLat" drop not null;
alter table public.orders alter column "pickupLng" drop not null;
alter table public.orders alter column "dropoffLat" drop not null;
alter table public.orders alter column "dropoffLng" drop not null;
