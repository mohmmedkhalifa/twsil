import 'package:flutter/material.dart';

/// Centralized UI label formatting for every technical value the API
/// sends (statuses, enums, codes). Backend values are NEVER changed by
/// this file - it only decides what text the user sees.
///
/// The app currently runs an Arabic interface (`locale: Locale('ar')`).
/// English translations ship alongside so enabling an English locale
/// later switches every label at once.
const String appLanguage = 'ar';

bool get _isEnglish => appLanguage == 'en';

/// Last-resort fallback for unknown values: never render raw
/// snake_case / enum text to the user.
String prettyValue(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return '-';
  return cleaned.replaceAll('_', ' ');
}

// ------------------------------------------------------------- orders

const Map<String, String> _orderStatusAr = {
  'payment_pending': 'بانتظار الدفع',
  'awaiting_captain': 'بانتظار الكابتن',
  'captain_assigned': 'تم تعيين الكابتن',
  'en_route_pickup': 'في الطريق للاستلام',
  'arrived_pickup': 'وصل نقطة الاستلام',
  'picked_up': 'تم استلام الطرد',
  'en_route_delivery': 'في الطريق للتسليم',
  'arrived_dropoff': 'وصل موقع التسليم',
  'delivered': 'تم التسليم',
  'completed': 'مكتمل',
  'cancelled': 'ملغي',
  // Legacy statuses that may still exist in old records.
  'accepted': 'تم قبول الطلب',
  'in_transit': 'جاري التوصيل',
};

const Map<String, String> _orderStatusEn = {
  'payment_pending': 'Awaiting payment',
  'awaiting_captain': 'Waiting for a captain',
  'captain_assigned': 'Captain assigned',
  'en_route_pickup': 'On the way to pickup',
  'arrived_pickup': 'Arrived at pickup',
  'picked_up': 'Package picked up',
  'en_route_delivery': 'On the way to delivery',
  'arrived_dropoff': 'Arrived at drop-off',
  'delivered': 'Delivered',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'accepted': 'Order accepted',
  'in_transit': 'In transit',
};

String orderStatusLabel(String status) =>
    (_isEnglish ? _orderStatusEn[status.trim()] : _orderStatusAr[status.trim()]) ??
    prettyValue(status);

// ------------------------------------------------- payments & subscriptions

const Map<String, String> _paymentStatusAr = {
  'awaiting_payment': 'بانتظار الدفع',
  'payment_submitted': 'تم إرسال الإيصال',
  'under_review': 'قيد المراجعة',
  'approved': 'تمت الموافقة',
  'rejected': 'مرفوض',
};

const Map<String, String> _paymentStatusEn = {
  'awaiting_payment': 'Awaiting payment',
  'payment_submitted': 'Receipt submitted',
  'under_review': 'Under review',
  'approved': 'Approved',
  'rejected': 'Rejected',
};

String paymentStatusLabel(String status) =>
    (_isEnglish ? _paymentStatusEn[status.trim()] : _paymentStatusAr[status.trim()]) ??
    prettyValue(status);

/// Subscriptions share the same status enum as payments.
String subscriptionStatusLabel(String status) => paymentStatusLabel(status);

// --------------------------------------------- captain profile lifecycle

const Map<String, String> _profileStatusAr = {
  'inactive': 'غير فعّال',
  'submitted': 'تم الإرسال',
  'under_review': 'قيد المراجعة',
  'active': 'فعّال',
  'rejected': 'مرفوض',
};

const Map<String, String> _profileStatusEn = {
  'inactive': 'Inactive',
  'submitted': 'Submitted',
  'under_review': 'Under review',
  'active': 'Active',
  'rejected': 'Rejected',
};

String profileStatusLabel(String status) =>
    (_isEnglish ? _profileStatusEn[status.trim()] : _profileStatusAr[status.trim()]) ??
    prettyValue(status);

// --------------------------------------------------- universal fallback

/// Tries every known mapping, so any widget can render any status
/// without leaking raw technical values.
String statusLabel(String status) {
  final key = status.trim();
  return orderStatusLabel(key) != prettyValue(key)
      ? orderStatusLabel(key)
      : paymentStatusLabel(key) != prettyValue(key)
          ? paymentStatusLabel(key)
          : verificationStatusLabel(key) != prettyValue(key)
              ? verificationStatusLabel(key)
              : profileStatusLabel(key) != prettyValue(key)
                  ? profileStatusLabel(key)
                  : prettyValue(key);
}

// ------------------------------------------------------- verification

const Map<String, String> _verificationAr = {
  'pending': 'قيد المراجعة',
  'approved': 'موثّق ومقبول',
  'rejected': 'مرفوض',
  'verification_pending': 'قيد المراجعة',
  'verification_approved': 'موثّق ومقبول',
  'verification_rejected': 'مرفوض',
};

const Map<String, String> _verificationEn = {
  'pending': 'Under review',
  'approved': 'Verified & approved',
  'rejected': 'Rejected',
  'verification_pending': 'Under review',
  'verification_approved': 'Verified & approved',
  'verification_rejected': 'Rejected',
};

String verificationStatusLabel(String status) =>
    (_isEnglish ? _verificationEn[status.trim()] : _verificationAr[status.trim()]) ??
    prettyValue(status);

// ------------------------------------------------------ transport type

const Map<String, String> _transportAr = {
  'car': 'سيارة',
  'motorcycle': 'دراجة نارية',
  'bicycle': 'دراجة هوائية',
  'other': 'أخرى',
};

const Map<String, String> _transportEn = {
  'car': 'Car',
  'motorcycle': 'Motorcycle',
  'bicycle': 'Bicycle',
  'other': 'Other',
};

String transportTypeLabel(String type) =>
    (_isEnglish ? _transportEn[type.trim()] : _transportAr[type.trim()]) ??
    prettyValue(type);

// -------------------------------------------------------- package size

const Map<String, String> _packageSizeAr = {
  'small': 'صغير (مغلف/أوراق)',
  'medium': 'متوسط (حقيبة/صندوق)',
  'large': 'كبير (أثاث/كرتونة)',
};

const Map<String, String> _packageSizeEn = {
  'small': 'Small (envelope/documents)',
  'medium': 'Medium (bag/box)',
  'large': 'Large (furniture/carton)',
};

String packageSizeLabel(String size) =>
    (_isEnglish ? _packageSizeEn[size.trim()] : _packageSizeAr[size.trim()]) ??
    prettyValue(size);

// ----------------------------------------------------- payment methods

const Map<String, String> _methodAr = {
  'jawwal_pay': 'جوّال باي',
  'bop_palestine': 'بنك فلسطين',
  'palpay': 'بال باي',
};

const Map<String, String> _methodEn = {
  'jawwal_pay': 'Jawwal Pay',
  'bop_palestine': 'Bank of Palestine',
  'palpay': 'PalPay',
};

String paymentMethodLabel(String method) =>
    (_isEnglish ? _methodEn[method.trim()] : _methodAr[method.trim()]) ??
    prettyValue(method);

// -------------------------------------------------------------- colors

Color statusColorFor(String status) {
  switch (status.trim()) {
    case 'approved':
    case 'active':
    case 'completed':
    case 'delivered':
      return const Color(0xFF16A34A);
    case 'under_review':
    case 'pending':
    case 'payment_submitted':
    case 'captain_assigned':
    case 'en_route_pickup':
    case 'arrived_pickup':
    case 'picked_up':
    case 'en_route_delivery':
    case 'arrived_dropoff':
    case 'in_transit':
    case 'accepted':
      return const Color(0xFFF59E0B);
    case 'rejected':
    case 'cancelled':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}
