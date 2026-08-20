-- ============================================================
-- Twsil: Supabase-native layer
-- RLS policies, Auth sync, updated_at triggers, order numbers,
-- Realtime publication, Storage policies.
-- Roles are read from public.users.role (single source of truth).
-- ============================================================

-- ---------- helpers ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer
set search_path = public
as $$ select exists (select 1 from public.users where id = auth.uid() and role = 'admin'); $$;

create or replace function public.is_captain(uid uuid) returns boolean
language sql stable security definer
set search_path = public
as $$ select exists (select 1 from public.users where id = uid and role = 'captain'); $$;

-- updated_at trigger -------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql
as $$ begin new."updatedAt" = now(); return new; end; $$;

-- order numbers ------------------------------------------------------------
create sequence if not exists public.order_numbers_seq start with 1;
create or replace function public.mktwsil_order_number()
returns text language plpgsql
as $$
declare n text;
begin
  n := 'TW' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.order_numbers_seq')::text, 4, '0');
  return n;
end; $$;
alter table public.orders alter column "orderNumber" set default public.mktwsil_order_number();

-- ---------- users / auth sync ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  v_phone text;
begin
  v_phone := coalesce(nullif(new.raw_user_meta_data ->> 'phone', ''), nullif(new.phone, ''));
  insert into public.users (id, "firstName", "lastName", phone, email, role, locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', split_part(coalesce(v_phone, new.email), '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    v_phone,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'customer'),
    'ar'
  )
  on conflict (id) do update set
    "firstName" = excluded."firstName",
    "lastName" = excluded."lastName",
    phone = excluded.phone,
    email = excluded.email,
    role = excluded.role;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Captain gate: customer -> captain (used by RPC below) --------------------
create or replace function public.request_captain_role(
  p_transport_type text,
  p_plate text,
  p_national_id text,
  p_city text,
  p_bio text
) returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  result jsonb;
begin
  if me is null then
    raise exception 'unauthenticated' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.users where id = me and role = 'captain') then
    return to_jsonb((select row_to_json(u.*) from (select * from public.captain_profiles where "userId" = me) u));
  end if;
  update public.users set role = 'captain' where id = me;
  insert into public.captain_profiles ("userId", "transportType", "plateNumber", "nationalId", city, bio)
  values (me, p_transport_type::public.captain_profiles_transporttype_enum, p_plate, p_national_id, p_city, p_bio);
  return to_jsonb((select row_to_json(u.*) from (select * from public.captain_profiles where "userId" = me) u));
end; $$;

-- ---------- RLS: enable ----------
alter table public.users enable row level security;
alter table public.captain_profiles enable row level security;
alter table public.orders enable row level security;
alter table public.order_payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.complaints enable row level security;
alter table public.reviews enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.order_timeline enable row level security;

-- ---------- policies: users ----------
drop policy if exists "users_select_own_or_admin" on public.users;
create policy "users_select_own_or_admin" on public.users
  for select using (id = auth.uid() or public.is_admin());
drop policy if exists "users_update_own_or_admin" on public.users;
create policy "users_update_own_or_admin" on public.users
  for update using (id = auth.uid() or public.is_admin());

-- ---------- captain_profiles ----------
drop policy if exists "profiles_select_all_auth" on public.captain_profiles;
create policy "profiles_select_all_auth" on public.captain_profiles
  for select using (auth.role() = 'authenticated');
drop policy if exists "profiles_update_own_or_admin" on public.captain_profiles;
create policy "profiles_update_own_or_admin" on public.captain_profiles
  for update using ("userId" = auth.uid() or public.is_admin());

-- ---------- orders ----------
drop policy if exists "orders_select_participant" on public.orders;
create policy "orders_select_participant" on public.orders
  for select using ("customerId" = auth.uid() or "captainId" = auth.uid() or public.is_admin());
drop policy if exists "orders_insert_customer" on public.orders;
create policy "orders_insert_customer" on public.orders
  for insert with check ("customerId" = auth.uid());
drop policy if exists "orders_update_participant" on public.orders;
create policy "orders_update_participant" on public.orders
  for update using ("customerId" = auth.uid() or "captainId" = auth.uid() or public.is_admin());

-- ---------- order_payments ----------
drop policy if exists "payments_select_owner" on public.order_payments;
create policy "payments_select_owner" on public.order_payments
  for select using (public.is_admin() or exists (
    select 1 from public.orders o
    where o.id = "orderId" and (o."customerId" = auth.uid() or o."captainId" = auth.uid())));
drop policy if exists "payments_insert_customer" on public.order_payments;
create policy "payments_insert_customer" on public.order_payments
  for insert with check (exists (
    select 1 from public.orders o
    where o.id = "orderId" and o."customerId" = auth.uid()));
drop policy if exists "payments_update_owner" on public.order_payments;
create policy "payments_update_owner" on public.order_payments
  for update using (public.is_admin() or exists (
    select 1 from public.orders o
    where o.id = "orderId" and o."customerId" = auth.uid()));

-- ---------- subscriptions ----------
drop policy if exists "subs_select_own_or_admin" on public.subscriptions;
create policy "subs_select_own_or_admin" on public.subscriptions
  for select using ("captainId" = auth.uid() or public.is_admin());
drop policy if exists "subs_insert_captain" on public.subscriptions;
create policy "subs_insert_captain" on public.subscriptions
  for insert with check ("captainId" = auth.uid());
drop policy if exists "subs_update_own_or_admin" on public.subscriptions;
create policy "subs_update_own_or_admin" on public.subscriptions
  for update using ("captainId" = auth.uid() or public.is_admin());

-- ---------- complaints ----------
drop policy if exists "complaints_select_own_or_admin" on public.complaints;
create policy "complaints_select_own_or_admin" on public.complaints
  for select using ("reporterId" = auth.uid() or public.is_admin());
drop policy if exists "complaints_insert_auth" on public.complaints;
create policy "complaints_insert_auth" on public.complaints
  for insert with check ("reporterId" = auth.uid());
drop policy if exists "complaints_update_own_or_admin" on public.complaints;
create policy "complaints_update_own_or_admin" on public.complaints
  for update using ("reporterId" = auth.uid() or public.is_admin());

-- ---------- reviews ----------
drop policy if exists "reviews_select_all" on public.reviews;
create policy "reviews_select_all" on public.reviews
  for select using (auth.role() = 'authenticated' and not "isHidden");
drop policy if exists "reviews_insert_participant" on public.reviews;
create policy "reviews_insert_participant" on public.reviews
  for insert with check ("reviewerId" = auth.uid() and exists (
    select 1 from public.orders o
    where o.id = "orderId" and (o."customerId" = auth.uid() or o."captainId" = auth.uid())));
drop policy if exists "reviews_update_admin" on public.reviews;
create policy "reviews_update_admin" on public.reviews
  for update using (public.is_admin());

-- ---------- conversations ----------
drop policy if exists "conv_select_participant" on public.conversations;
create policy "conv_select_participant" on public.conversations
  for select using ("customerId" = auth.uid() or "captainId" = auth.uid() or public.is_admin());
drop policy if exists "conv_insert_auth" on public.conversations;
create policy "conv_insert_auth" on public.conversations
  for insert with check ("customerId" = auth.uid());
drop policy if exists "conv_update_participant" on public.conversations;
create policy "conv_update_participant" on public.conversations
  for update using ("customerId" = auth.uid() or "captainId" = auth.uid() or public.is_admin());

-- ---------- messages ----------
drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select using (exists (
    select 1 from public.conversations c
    where c.id = "conversationId"
      and (c."customerId" = auth.uid() or c."captainId" = auth.uid() or public.is_admin())));
drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant" on public.messages
  for insert with check ("senderId" = auth.uid() and exists (
    select 1 from public.conversations c
    where c.id = "conversationId"
      and (c."customerId" = auth.uid() or c."captainId" = auth.uid())));
drop policy if exists "messages_update_read" on public.messages;
create policy "messages_update_read" on public.messages
  for update using (exists (
    select 1 from public.conversations c
    where c.id = "conversationId"
      and (c."customerId" = auth.uid() or c."captainId" = auth.uid())))
  with check ("isRead" = true and "senderId" = auth.uid());

-- ---------- notifications ----------
drop policy if exists "notif_select_own" on public.notifications;
create policy "notif_select_own" on public.notifications
  for select using ("userId" = auth.uid() or public.is_admin());
drop policy if exists "notif_update_own" on public.notifications;
create policy "notif_update_own" on public.notifications
  for update using ("userId" = auth.uid());

-- ---------- order_timeline ----------
drop policy if exists "timeline_select_participant" on public.order_timeline;
create policy "timeline_select_participant" on public.order_timeline
  for select using (public.is_admin() or exists (
    select 1 from public.orders o
    where o.id = "orderId" and (o."customerId" = auth.uid() or o."captainId" = auth.uid())));
drop policy if exists "timeline_insert_participant" on public.order_timeline;
create policy "timeline_insert_participant" on public.order_timeline
  for insert with check ("actorId" = auth.uid() and exists (
    select 1 from public.orders o
    where o.id = "orderId" and (o."customerId" = auth.uid() or o."captainId" = auth.uid())));

-- ---------- updated_at triggers ----------
drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();
drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();
drop trigger if exists trg_profiles_updated_at on public.captain_profiles;
create trigger trg_profiles_updated_at before update on public.captain_profiles
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

-- ---------- realtime ----------
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.orders;

-- ---------- storage: receipts ----------
update storage.buckets set public = true where id = 'twsil-images';
drop policy if exists "receipts_select_public" on storage.objects;
create policy "receipts_select_public" on storage.objects
  for select using (bucket_id = 'twsil-images');
drop policy if exists "receipts_insert_auth" on storage.objects;
create policy "receipts_insert_auth" on storage.objects
  for insert with check (bucket_id = 'twsil-images' and auth.role() = 'authenticated');
drop policy if exists "receipts_delete_owner" on storage.objects;
create policy "receipts_delete_owner" on storage.objects
  for delete using (bucket_id = 'twsil-images' and owner = auth.uid());