# متطلبات التجهيز والإطلاق | Launch Requirements

هذا الملف يحدد كل المعلومات والإعدادات المطلوبة منك (صاحب المشروع) لتجهيز المنصة وإطلاقها رسمياً.
املأ الفراغات `____` ثم استخدم القيم في ملفات البيئة والتطبيقات. لا تشارك هذا الملف مع أي جهة خارجية؛ يحتوي على أسرار.

---

## 1) الهوية والأسماء

| البند | القيمة المطلوبة | الإجابة |
|---|---|---|
| اسم التطبيق (للمستخدمين) | مثال: «توصيل» | ____ |
| اسم تطبيق السائق/العميل | نفس التطبيق (دوران في حساب واحد) | ____ |
| وصف قصير للتسويق | جملة واحدة | ____ |
| Package ID (Android) | `com.twsil.app` — لا يُغيّر بعد النشر | ____ |
| Bundle ID (iOS) | `com.twsil.app` | ____ |
| الشعار (Logo) | ملف PNG/SVG بقياس 1024×1024 | ____ |
| الألوان الرسمية | الحالي: أخضر `#00875A` — أو مغيّرة؟ | ____ |
| أرقام التواصل للدعم | هاتف + واتساب | ____ |

---

## 2) الخادم (Server)

| البند | القيمة المطلوبة | الإجابة |
|---|---|---|
| مزوّد الخادم | مثال: DigitalOcean / Hetzner / سيرفر محلي | ____ |
| مواصفات مقترحة | 2 vCPU / 4GB RAM / 50GB SSD (يكفي لبداية) | ____ |
| نظام التشغيل | Ubuntu 22.04+ | ____ |
| عنوان IP | `____` | ____ |
| مستخدم SSH | `root` أو مستخدم آخر | ____ |
| Node.js | v22+ (LTS) على الخادم | ____ |
| طريقة التشغيل | PM2 / Docker / systemd — نختار لاحقاً | ____ |
| النسخ الاحتياطي | مسار تخزين نسخ قاعدة البيانات والصور | ____ |

---

## 3) النطاقات والشهادات

| البند | القيمة المطلوبة | الإجابة |
|---|---|---|
| نطاق الـ API | مثال: `api.twsil.ps` | ____ |
| نطاق لوحة الإدارة | مثال: `admin.twsil.ps` | ____ |
| نطاق الموقع التسويقي | اختياري | ____ |
| مزوّد النطاق | ____ | ____ |
| SSL | Let's Encrypt مجاني عبر Certbot / Caddy | سيتولى الفريق |

---

## 4) قاعدة البيانات

| البند | القيمة المطلوبة | الإجابة |
|---|---|---|
| النوع | PostgreSQL 16 (موصى به للإنتاج) أو SQLite | ____ |
| اسم قاعدة البيانات | `twsil` | ____ |
| المستخدم | `twsil_user` | ____ |
| كلمة المرور | كلمة قوية من 20+ حرفاً | ____ |
| المنفذ | `5432` | ____ |
| (اختياري) مضيف خارجي | مثال: Neon / Supabase / RDS | ____ |

---

## 5) ضبط بيئة الإنتاج `backend/.env`

| المتغير | القيمة | الإجابة |
|---|---|---|
| `NODE_ENV` | `production` | ____ |
| `BASE_URL` | `https://api.twsil.ps` | ____ |
| `JWT_SECRET` | كلمة سر عشوائية طويلة (`openssl rand -hex 32`) | ____ |
| `JWT_EXPIRES_IN` | `7d` | ____ |
| `DATABASE_TYPE` | `postgres` | ____ |
| `DB_HOST/DB_PORT/DB_USERNAME/DB_PASSWORD/DB_NAME` | من القسم 4 | ____ |
| `ADMIN_PHONE` + `ADMIN_PASSWORD` | رقم وكلمة مرور الإدارة (غيّر الافتراضي) | ____ |
| `UPLOAD_DIR` | `uploads` | ____ |
| `MAX_UPLOAD_MB` | `10` | ____ |
| الرسوم: اشتراك `10` / خدمة `1` / أساس `5` / لكل كم `2` | عدّلها إن تغيّرت | ____ |

---

## 6) بيانات الدفع والتحويل (الأهم للمراجعة اليدوية)

تُعرض هذه البيانات للمستخدمين في شاشة الدفع، وسيراجعها الأدمن يدوياً.

| البند | المطلوب | الإجابة |
|---|---|---|
| بنك فلسطين (Bank of Palestine) — رقم IBAN | `____` | ____ |
| اسم صاحب الحساب (كما في البنك) | `____` | ____ |
| Jawwal Pay — رقم المحفظة | `____` | ____ |
| PalPay — رقم / بيانات الحساب | `____` | ____ |
| (اختياري) صورة QR لكل طريقة دفع | ملفات PNG | ____ |
| تعليمات الدفع للمستخدم | نص يظهر داخل التطبيق | ____ |
| ملاحظة: هل ستدفع رسوم التطوير من هذا الحساب؟ | نعم/لا | ____ |

> تُخطر لوحة الإدارة فور وصول إيصال جديد، فيقوم الأدمن بتدقيقه (إيصال واضح؟ المبلغ مطابق؟ رقم المعاملة صحيح؟) ثم اعتماده أو رفضه.

---

## 7) حسابات المتاجر والتحميل

| البند | المطلوب | الإجابة |
|---|---|---|
| حساب Google Play Console | بريد خاص + 25$ رسوم التسجيل | ____ |
| حساب Apple Developer | 99$/سنة | ____ |
| Keystore للتوقيع (Android) | سنولّده ونحفظه — احتفظ بنسخة احتياطية آمنة | ____ |
| بيانات المتجر: وصف، لقطات شاشة عربية/إنجليزية | جاهزة لاحقاً | ____ |
| حسابات الاختبار (Testers) | قائمة بجوالات قائمة الاختبارات | ____ |
| سياسة الخصوصية — رابط | صفحة ويب إلزامية للمتاجر | ____ |
| شروط الاستخدام | صفحة ويب | ____ |

---

## 8) خرائط OpenStreetMap (الإعداد)

التطبيق يستخدم `flutter_map` + بلاطات OSM مجانية — **لا مفاتيح ولا إعدادات مطلوبة للإطلاق**. لمحطات إنتاجية أسرع وأضمن:

| الخيار | التفاصيل | مطلوب منك؟ |
|---|---|---|
| الافتراضي (الآن) | `tile.openstreetmap.org` — مجاني، يكفي لعشرات آلاف المستخدمين | لا |
| مزوّد تجاري بديل | Carto Basemaps / MapTiler / Geoapify — بلاطات أسرع مع سجل استخدام | اختياري — حساب + مفتاح |
| استضافة ذاتية (المدى الطويل) | سيرفر بلاطات من OpenStreetMap ("switch2osm") — يُنصح مع انتشار واسع | اختياري — سيرفر إضافي |
| المسار | عنوان البلاطات يُعدَّل من `mobile/lib/core/config.dart` (متغير `TILE_URL`) | لا شيء الآن |

> ملاحظة: التتبع المباشر يعتمد على موقع السائق (GPS) فقط، وليس على الخريطة نفسها.

---

## 9) الإشعارات الفورية FCM (Firebase) — تم الربط، المتبقي منك:

المشروع أصبح مهيأً بالكامل (باكند + تطبيق). يتبقى خطوتان من حسابك فقط:

| # | الخطوة | الحالة |
|---|---|---|
| 1 | أنشأت مشروع Firebase `twsil-db653` وأضفت تطبيق Web وأعطيت الإعدادات | ✅ تم |
| 2 | `cd mobile && dart pub global activate flutterfire_cli && flutterfire configure --project=twsil-db653` — يضيف `google-services.json` ويثبّت `firebase_options.dart` بـ Android App ID | **مطلوب منك** (ثوانٍ) |
| 3 | إنشاء **ملف الحساب الخدمي** للباكند: Firebase Console → ⚙️ Project settings → Service accounts → Generate new private key → احفظه باسم `backend/firebase-service-account.json` | **مطلوب منك** |
| 4 | إضافة `FIREBASE_SERVICE_ACCOUNT_PATH=firebase-service-account.json` إلى `backend/.env` | سنضيفه |
| 5 | (Android) تمكين Cloud Messaging في لوحة Firebase + التأكد أن `google-services.json` ضمن `mobile/android/app/` | ✅ تلقائي عبر flutterfire |
| 6 | (iOS لاحقاً) `GoogleService-Info.plist` + مفاتيح APNs من Apple | عند تجهيز iOS |

بعدها تعمل الإشعارات فوراً: إيصال جديد → تنبيه للأدمن، حالة طلب جديدة → تنبيه للعميل/السائق، حتى لو كان التطبيق مغلقاً.

---

## 10) مستودع صور الإيصالات (S3-Compatible)

**الوضع الحالي:** التخزين محلي على مجلد `backend/uploads/` — مناسب للتجربة فقط.

**الخيار الموصى به — Supabase Storage (بلا أي حساب خارجي):** يدعم بروتوكول S3، وبياناته موجودة أصلاً في المشروع نفسه.

| # | الخطوة | التفاصيل |
|---|---|---|
| 1 | لوحة Supabase → **Storage** → **New bucket** | الاسم: `twsil-images` → فعّل **Public bucket** حتى تُعرض الصور بلا صلاحيات |
| 2 | **Project Settings** → **Storage** → قسم **S3 Access Keys** | **Create access key** → انسخ `Access Key ID` + `Secret Access Key` |
| 3 | عبّئ في `backend/.env` (من قائمة 11 أدناه) | نموذج Supabase أدناه |

```
STORAGE_DRIVER=s3
S3_ENDPOINT=https://ymqtrsnikcicywxtfjsx.supabase.co/storage/v1/s3
S3_REGION=ap-south-1
S3_BUCKET=twsil-images
S3_ACCESS_KEY_ID=...
S3_SECRET_ACCESS_KEY=...
S3_PUBLIC_URL=https://ymqtrsnikcicywxtfjsx.supabase.co/storage/v1/object/public/twsil-images
S3_FORCE_PATH_STYLE=true
```

> **بديل مستقل:** Cloudflare R2 (مجاني 10GB شهرياً) بخطوات مشابهة و`S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com` و`S3_REGION=auto` ودومين عام للصور.
> **بديل داخل جوجل:** Google Cloud Storage (XML API بمفاتيح HMAC) — كل الخدمات تحت GCP.
> عند التفعيل تُحفظ الصور الجديدة في السحابة مباشرة؛ الصور القديمة تُرحَّل لاحقاً بأمر بسيط.

---

## 11) الرفع على Firebase Hosting + Cloud Functions (المنصة كاملة — تم التجهيز)

كل ملفات النشر جاهزة في المشروع (`firebase.json` + `.firebaserc` + `backend/src/firebase-entry.ts`). خطوات التنفيذ منك:

| # | الخطوة | الأمر |
|---|---|---|
| 1 | تسجيل الدخول لـ Firebase | `npx firebase-tools login` |
| 2 | التأكد أن `firebase-tools` موجود (موجود عندك) | `firebase --version` |
| 3 | رفع الـ API (NestJS كـ Cloud Function — يدعم Socket.io) | `cd backend && npm run build` ثم من جذر المشروع: `firebase deploy --only functions` |
| 4 | رفع لوحة التحكم (تسأل هل تريد Hosting؟ نعم، الملفات جاهزة في `admin/build/web`) | `cd admin && flutter build web --release --no-web-resources-cdn` ثم من جذر المشروع: `firebase deploy --only hosting` |
| 5 | تفعيل خطة Blaze (حتى تعمل Functions — البطاقة مطلوبة لكن التكلفة بالدولار الرمزي) | لوحة Firebase → Upgrade |
| 6 | رفع API هو عنوان: `https://us-central1-twsil-db653.cloudfunctions.net/api` ولوحة التحكم: `https://twsil-db653.web.app` | |

**قبل الرفع — قاعدة البيانات:** Cloud Functions لا تدعم SQLite (ملفات مؤقتة). اضبط PostgreSQL:
- أنشئ مثيل Cloud SQL (PostgreSQL 16) من Google Cloud، أو أي PostgreSQL خارجي
- عبّئ `backend/.env`: `DATABASE_TYPE=postgres` + بيانات الاتصال + `DATABASE_SYNC=true` للإنشاء التلقائي للجداول (أول مرة فقط)
- استخدم أسرار Functions: `firebase functions:secrets:set JWT_SECRET` وغيرها بدل إرسال المفاتيح في الكود

**أثناء التطوير المحلي:** يستمر العمل كما هو (SQLite + localhost:4000) — الرفع لا يغيّر شيئاً محلياً.

---

## 12) قائمة التحقق النهائية قبل الإطلاق (تعليمات تنفيذية)

1. [ ] إنشاء `backend/.env` بقيم الأقسام 4–5 ثم `npm run build` ثم تشغيل محلي للاختبار
2. [ ] تشغيل `npm run seed` وتغيير كلمة مرور الأدمن فوراً
3. [ ] رفع النسخة التجريبية: `flutter build apk --release --dart-define=API_BASE_URL=https://us-central1-twsil-db653.cloudfunctions.net/api` (أو نفس دومين اللوحة `/api`)
4. [ ] اختبار الدفع الكامل: تسجيل عميل → طلب → إيصال → اعتماد الأدمن → سائق → تسليم → تقييم
5. [ ] تنفيذ خطوات FCM (القسم 9) واختبار إشعار مع إغلاق التطبيق
6. [ ] تنفيذ خطوات مستودع الصور (القسم 10)
7. [ ] الرفع على Firebase (القسم 11) وتجربة اللوحة من الجوال عبر HTTPS
8. [ ] رفع سياسة الخصوصية وشروط الاستخدام
9. [ ] إصدار نسخة تجريبية (Play Console Closed Testing) مع مجموعة اختبار
10. [ ] النشر الرسمي + نسخ احتياطي دوري يومي لقاعدة البيانات

---

## 13) مستندات نهائية (تُسلَّم لك عند الإطلاق)

- كلمة مرور الأدمن الجديدة
- بيانات مشروع Firebase والخدمات
- ملف Keystore وكلمة مروره (أمان)
- تسعير الرسوم كما هو مطبق في النظام
- تقرير أمان: JWT، تشفير كلمات المرور (bcrypt)، NoSQL/SQL injection محمي