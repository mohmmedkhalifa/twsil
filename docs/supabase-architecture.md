# البنية الجديدة: Supabase-Native (لا مزيد من NestJS)

قرار إلغاء NestJS تدريجياً واستبداله بـ Supabase الكاملة:

| القديم | الجديد |
|---|---|
| NestJS على الخادم | لا خادم — PostgREST مباشر (من Flutter والويب) |
| TypeORM | جداول Supabase + RLS + RPCs |
| JWT مخصص (HS256) | Supabase Auth (email/phone + password) |
| Socket.io للشات | Supabase Realtime (broadcast + postgres_changes) |
| firebase-admin + مفاتيح | Edge Functions فقط (مع Secrets) |
| رفع صور عبر الخادم | Storage مباشر من العميل + RLS |

## الحالة (16/8/2026)

- ✅ الطبقة سحابية كاملة حية على `twsil-db653` ([ref] ymqtrsnikcicywxtfjsx)
- ⏳ Flutter يُرحَّل لاحقاً (لا يزال يتحدث عبر NestJS المحلي :4000 حتى ذلك الحين)
- ⏳ لوحة التحكم تُرحَّل لاحقاً
- ⏳ Edge Function للإشعارات (FCM) والعمليات الإدارية الحساسة

## المفاتيح

- **PUB (publishable، للعميل):** `REDACTED_SB_PUBLISHABLE_e7cwhdA0`
- **SEC (secret، للخادم فقط):** `REDACTED_SB_SECRET`
- كلاهما يُمرَّر كـ `apikey` + `Authorization: Bearer`. الـ secret يتجاوز RLS.
- ⚠️ مفاتيح legacy (anon/service_role بصيغة JWT) لم تُستخدم — الجديدة تعمل على كل الأسطح. إن طلبت GoTrue `apikey` فها هي تعمل.

## الاتصالات

| سطح | الرابط |
|---|---|
| REST (PostgREST) | `https://ymqtrsnikcicywxtfjsx.supabase.co/rest/v1/...` |
| Auth | `https://ymqtrsnikcicywxtfjsx.supabase.co/auth/v1/...` |
| Storage | `https://ymqtrsnikcicywxtfjsx.supabase.co/storage/v1/...` |
| Realtime | `wss://ymqtrsnikcicywxtfjsx.supabase.co/realtime/v1` (بمفتاح apikey) |
| قاعدة (pooler) | `aws-0-ap-south-1.pooler.supabase.com:6543` postgres.ymqtrsnikcicywxtfjsx / CHANGE_ME_DB_PASSWORD |

## الدروس المهمة (ادخرت ساعات)

1. **أرقام الهاتف يجب أن تكون E.164** (`+970...`) — يرجع `validation_failed` بغيرها.
2. **`auth.identities.email` عمود مولّد** (generated) — ممنوع الإدراج المباشر فيه.
3. **إنشاء مستخدم يدوياً داخل `auth.users` يفسد GoTrue** (خطأ "Database error querying schema") — أنشئ دائماً عبر `POST /auth/v1/admin/users` بالـ secret.
4. الحساب الأمين (أُنشئ عبر API):
   - email: `admin@twsil.ps` — password: `Admin@12345` — phone: `+970599999999`
   - id: `75a739bd-dd5d-4351-aa34-e26b409da674` (هو نفسه public.users id)
5. `passwordHash` في users بلا default عند TypeORM — عُدّل لـ `''`؛ الـ trigger يكتب صفاً عند إنشاء مستخدم.
6. كل سياسات RLS تقرأ الدور من `public.users.role` (دالة `is_admin()` secure definer).
7. المراجعات المخفية: الشرط `is_admin() or not "isHidden"` — أمين يرى الجميع.

## ما أُنشئ في Supabase (migrations)

- `supabase/migrations/0000_baseline.sql` — مخطط TypeORM السابق (مرجعي فقط)
- `supabase/migrations/0001_rls_auth_realtime.sql` — الطبقة: RLS، trigger، updated_at، ترتيب الطلبات، عموم البكت twsil-images، publication```

Realtime: `orders` + `conversations` + `messages` في `supabase_realtime`.

## RPCs المعدّة

- `request_captain_role(transportType,plate,nationalId,city,bio)` — يهبه الدور `captain` وينشئ الملف التعريفي (ممنوع على من ليس مشتركاً؟ لا — فقط يرفع الدور). استدعاء: `POST /rest/v1/rpc/request_captain_role` مع بيانات أعمدة p_*.

## مستخدمو الاختبار في auth.users

- الأمين: admin@twsil.ps / Admin@12345
- زبون/كابتن تجريبي: `twtest1786882846@twsil.ps` / Test@12345 (id 19bd3b24...) — أصبح كابتن عبر RPC، له طلب TW20260816-0001 + إيصال في storage.

## عمل الأدمن الآن عبر RLS فقط:

قراءة كل الجداول، تحديث المراجعات (إخفاء)، تحديث الطلبات (تغيير الحالة/الكابتن)، تحديث users (حظر). أي حقل إضافي لإدارة أعمق → دالة RPC جديدة.
## Edge Function: fcm (نُشرت 16/8/2026)

- رابط: `https://ymqtrsnikcicywxtfjsx.supabase.co/functions/v1/fcm` (بدون verify-jwt — المصادقة بسرّنا)
- أسرار المشروع: `FIREBASE_SERVICE_ACCOUNT` (JSON كامل) + `TW_FN_SECRET` (المستخدم داخلياً)
- TW_FN_SECRET الحالي: (في /tmp/opencode/tw-fn-secret.txt ولا يُحفظ في الريبو)
- البودي: `{userIds[], title, body, type?, data?}` + header `x-twsil-secret`
- يقوم بـ: قراءة توكنات fcm من users → إرسال FCM v1 (OAuth2 RS256 عبر WebCrypto) → إدراج صفوف notifications
- الاستجابة: `{sent, failed[], missing}`
- النشر المعتمد: `supabase functions deploy fcm --use-api` (بما أن docker بطيء بالشبكة) و `--no-verify-jwt`
- مقترح لاحقاً: زناد pg_net على orders ليرسل تلقائياً عند تغيّر الحالة

## لوحة التحكم (تم الاندماج 16/8/2026)

- `admin/lib/core/api.dart` أعيد بناؤه: PostgREST مباشر (لا dio إلى /api) — نفس أسطح الشاشات القديمة مع تلميحات FK بأسماء الأعمدة.
- تسجيل دخول: `admin@twsil.ps` بكلمة السر عبر `auth/v1/token` + تحقق role=admin من users.
- `admin_stats()` RPC: إحصائيات اللوحة (security definer + is_admin).
- تلميحات الدمج الصحيحة (أعمدة وليست أسماء قيود!): `users!customerId`, `users!captainId`, `users!userId`, `users!reporterId`, `users!reviewerId`, `orders!orderId`.
- مراجعة الإيصال approve → الطلب يصير awaiting_captain؛ request_receipt → payment_submitted.
- تفعيل اشتراك → captain_profiles: active + 30 يوم + متاح.
- الصور القديمة رُحّلت: `backend/uploads/receipts/*` → storage/public مع تحديث روابط DB.
- النشر: `flutter build web --release --no-web-resources-cdn` → `firebase deploy --only hosting` → https://twsil-db653.web.app (استضافة ثابتة بلا أي rewrite /api).
