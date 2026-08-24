-- ============================================================
-- Migration 0004: Global timestamp consistency ("updatedAt")
--
-- Strategy (single source of truth):
--   * Every mutable table carries a camelCase quoted column
--     "updatedAt" (timestamp without time zone), matching the
--     TypeORM entities' @UpdateDateColumn() mapping 1:1.
--   * The column is maintained by BOTH TypeORM (on save/update)
--     and a BEFORE UPDATE trigger per table so rows changed from
--     outside the API (SQL editor, RPCs) stay correct too.
--   * Tables that are insert-only (messages, reviews,
--     conversations, notifications, order_timeline) intentionally
--     have no updatedAt anywhere - entity or database.
--
-- This migration is idempotent and safe to re-run.
-- ============================================================

-- ---------- 1. Ensure the column exists everywhere it belongs ----------
alter table public.users             add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.captain_profiles  add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.orders            add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.order_payments    add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.subscriptions     add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.complaints        add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.captain_offers    add column if not exists "updatedAt" timestamp without time zone not null default now();
alter table public.captain_availability add column if not exists "updatedAt" timestamp without time zone not null default now();

-- ---------- 2. Trigger helper (camelCase, quoted) ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql
as $$ begin new."updatedAt" = now(); return new; end; $$;

-- ---------- 3. Attach/rebuild triggers on every mutable table ----------
drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.captain_profiles;
create trigger trg_profiles_updated_at before update on public.captain_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();

drop trigger if exists trg_payments_updated_at on public.order_payments;
create trigger trg_payments_updated_at before update on public.order_payments
  for each row execute function public.set_updated_at();

drop trigger if exists trg_subs_updated_at on public.subscriptions;
create trigger trg_subs_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

drop trigger if exists trg_complaints_updated_at on public.complaints;
create trigger trg_complaints_updated_at before update on public.complaints
  for each row execute function public.set_updated_at();

drop trigger if exists trg_captain_offers_updated_at on public.captain_offers;
create trigger trg_captain_offers_updated_at before update on public.captain_offers
  for each row execute function public.set_updated_at();

drop trigger if exists trg_captain_availability_updated_at on public.captain_availability;
create trigger trg_captain_availability_updated_at before update on public.captain_availability
  for each row execute function public.set_updated_at();

-- ---------- 4. New captains must never start active ----------
-- Aligns the table default with the entity default and the backend
-- registration flow: verification pending, inactive, unavailable.
alter table public.captain_profiles alter column "isActive" set default false;

-- Remove the legacy INSERT trigger that force-reset every new profile.
-- The backend already inserts correct initial state, the table defaults
-- above cover direct SQL/RPC paths, and the trigger silently corrupted
-- legitimate inserts (e.g. seeding approved captains).
drop trigger if exists trg_new_captain_pending on public.captain_profiles;
drop function if exists public.enforce_new_captain_pending();
