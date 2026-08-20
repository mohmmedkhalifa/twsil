-- ============================================================
-- Clean Test Data Script (Preserving Super Admin)
-- Safely removes test operational data without touching schema or Super Admin account
-- ============================================================

BEGIN;

-- 1. Identify Super Admin user IDs to protect
CREATE TEMP TABLE temp_admin_ids AS
SELECT id FROM public.users WHERE role = 'admin';

-- If no admin exists in public.users, protect users with role = 'admin' or email containing 'admin'
INSERT INTO temp_admin_ids (id)
SELECT id FROM auth.users 
WHERE raw_user_meta_data->>'role' = 'admin' OR email LIKE '%admin%'
ON CONFLICT DO NOTHING;

-- 2. Delete operational test data in dependency order
DELETE FROM public.messages;
DELETE FROM public.conversations;
DELETE FROM public.reviews;
DELETE FROM public.complaints;
DELETE FROM public.order_timeline;
DELETE FROM public.order_payments;
DELETE FROM public.orders;
DELETE FROM public.subscriptions;
DELETE FROM public.notifications;

-- 3. Delete Captain Availability & Captain Profiles for non-admins
DELETE FROM public.captain_availability 
WHERE "captainId" NOT IN (SELECT id FROM temp_admin_ids);

DELETE FROM public.captain_profiles 
WHERE "userId" NOT IN (SELECT id FROM temp_admin_ids);

-- 4. Delete non-admin users from public.users
DELETE FROM public.users 
WHERE id NOT IN (SELECT id FROM temp_admin_ids);

-- 5. Delete non-admin users from auth.users (if permissions allow)
DELETE FROM auth.users 
WHERE id NOT IN (SELECT id FROM temp_admin_ids);

-- 6. Clean storage objects for deleted accounts in twsil-images bucket
DELETE FROM storage.objects 
WHERE bucket_id = 'twsil-images' 
  AND owner NOT IN (SELECT id::text FROM temp_admin_ids);

DROP TABLE temp_admin_ids;

COMMIT;
