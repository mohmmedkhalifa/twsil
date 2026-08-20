// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'توصيل';

  @override
  String get tagline => 'منصة التوصيل اللامركزية';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get password => 'كلمة المرور';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get registerAsCustomer => 'سجّل كعميل';

  @override
  String get registerAsCaptain => 'سجّل كسائق توصيل';

  @override
  String get transportType => 'وسيلة النقل';

  @override
  String get car => 'سيارة';

  @override
  String get motorcycle => 'دراجة نارية';

  @override
  String get bicycle => 'دراجة هوائية';

  @override
  String get other => 'أخرى';

  @override
  String get plateNumber => 'رقم اللوحة';

  @override
  String get nationalId => 'رقم الهوية';

  @override
  String get city => 'المدينة';

  @override
  String get createOrder => 'طلب توصيل جديد';

  @override
  String get pickupAddress => 'عنوان الاستلام';

  @override
  String get dropoffAddress => 'عنوان التسليم';

  @override
  String get pickupOnMap => 'حدد نقطة الاستلام على الخريطة';

  @override
  String get dropoffOnMap => 'حدد نقطة التسليم على الخريطة';

  @override
  String get packageDescription => 'وصف الطرد';

  @override
  String get packageSize => 'حجم الطرد';

  @override
  String get small => 'صغير';

  @override
  String get medium => 'متوسط';

  @override
  String get large => 'كبير';

  @override
  String get weightKg => 'الوزن (كغم)';

  @override
  String get distance => 'المسافة';

  @override
  String get deliveryFee => 'رسوم التوصيل';

  @override
  String get serviceFee => 'رسوم الخدمة';

  @override
  String get total => 'الإجمالي';

  @override
  String get continueToPayment => 'المتابعة للدفع';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get jawwalPay => 'جوّال باي';

  @override
  String get bankOfPalestine => 'بنك فلسطين';

  @override
  String get palPay => 'بال باي';

  @override
  String get uploadReceipt => 'رفع صورة الإيصال';

  @override
  String get transactionNumber => 'رقم المعاملة (اختياري)';

  @override
  String get transferDate => 'تاريخ التحويل (اختياري)';

  @override
  String get submitPayment => 'تأكيد الدفع';

  @override
  String get awaitingPayment => 'بانتظار الدفع';

  @override
  String get paymentSubmitted => 'تم إرسال الدفع';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get paymentApproved => 'تمت الموافقة على الدفع';

  @override
  String get paymentRejected => 'تم رفض الدفع';

  @override
  String get trackOrder => 'تتبع الطلب';

  @override
  String get orderHistory => 'طلباتي';

  @override
  String get activeOrders => 'الطلبات النشطة';

  @override
  String get availableOrders => 'الطلبات المتاحة';

  @override
  String get accept => 'قبول';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delivered => 'تم التسليم';

  @override
  String get confirmDelivery => 'تأكيد الاستلام';

  @override
  String get rate => 'تقييم';

  @override
  String get comments => 'ملاحظات';

  @override
  String get chat => 'الدردشة';

  @override
  String get send => 'إرسال';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get home => 'الرئيسية';

  @override
  String get orders => 'الطلبات';

  @override
  String get captainPanel => 'لوحة السائق';

  @override
  String get subscription => 'الاشتراك';

  @override
  String get subscriptionFee => 'رسوم الاشتراك الشهري';

  @override
  String get shekels => 'شيكل';

  @override
  String get subscribe => 'اشترك الآن';

  @override
  String get subscriptionActive => 'الاشتراك فعّال';

  @override
  String get subscriptionInactive => 'الاشتراك غير فعّال';

  @override
  String get verification => 'التحقق من الهوية';

  @override
  String get verificationPending => 'التحقق قيد المراجعة';

  @override
  String get verificationApproved => 'تم التحقق';

  @override
  String get verificationRejected => 'تم رفض التحقق';

  @override
  String get verificationStatus => 'حالة التوثيق';

  @override
  String get submitVerification => 'تقديم الوثائق';

  @override
  String get idCardImage => 'صورة الهوية';

  @override
  String get licenseImage => 'صورة الرخصة';

  @override
  String get startPickup => 'بدء الرحلة للاستلام';

  @override
  String get arrivePickup => 'وصلت لنقطة الاستلام';

  @override
  String get pickedUp => 'استلمت الطرد';

  @override
  String get startDelivery => 'بدأ توصيل الطرد';

  @override
  String get arriveDropoff => 'وصلت للوجهة';

  @override
  String get enterPickupCode => 'أدخل رمز الاستلام من العميل';

  @override
  String get sendLocation => 'إرسال موقعي';

  @override
  String get availableToggle => 'متاح لاستقبال الطلبات';

  @override
  String get notAvailable => 'غير متاح';

  @override
  String get status => 'الحالة';

  @override
  String get customer => 'عميل';

  @override
  String get captain => 'سائق';

  @override
  String get admin => 'مدير';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get cancelReason => 'سبب الإلغاء';

  @override
  String get writeMessage => 'اكتب رسالة...';

  @override
  String get noOrders => 'لا توجد طلبات';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get noMessages => 'لا توجد رسائل بعد';

  @override
  String get wrongPhoneOrPassword => 'رقم الهاتف أو كلمة المرور غير صحيحة';

  @override
  String get phoneExists => 'رقم الهاتف مسجل مسبقاً';

  @override
  String get networkError => 'خطأ في الاتصال بالخادم';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get welcome => 'أهلاً بك';

  @override
  String get captainHomeTitle => 'لوحة التحكم';

  @override
  String get myOrders => 'طلباتي';

  @override
  String get earnings => 'الأرباح';

  @override
  String get deliveriesCount => 'عدد التوصيلات';

  @override
  String get rating => 'التقييم';

  @override
  String get sendComplaint => 'تقديم شكوى';

  @override
  String get complaintSubject => 'موضوع الشكوى';

  @override
  String get complaintDescription => 'وصف الشكوى';

  @override
  String get submit => 'إرسال';

  @override
  String get totalEarned => 'إجمالي الأرباح';

  @override
  String get currency => '₪';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get success => 'تم بنجاح';

  @override
  String get error => 'حدث خطأ';

  @override
  String get splashLoading => 'جارٍ التحميل...';
}
