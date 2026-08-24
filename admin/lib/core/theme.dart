import 'package:flutter/material.dart';

class ATheme {
  static const primary = Color(0xFF00875A);
  static const accent = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0xFFE8ECEF)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF8FAFB)),
        headingTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        dataTextStyle: TextStyle(fontSize: 13),
      ),
    );
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'approved':
    case 'active':
    case 'completed':
    case 'delivered':
    case 'verification_approved':
      return const Color(0xFF16A34A);
    case 'under_review':
    case 'pending':
    case 'open':
    case 'in_progress':
    case 'verification_pending':
      return const Color(0xFFF59E0B);
    case 'rejected':
    case 'cancelled':
    case 'verification_rejected':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'approved':
      return 'مقبول';
    case 'rejected':
      return 'مرفوض';
    case 'under_review':
      return 'قيد المراجعة';
    case 'awaiting_payment':
      return 'بانتظار الدفع';
    case 'payment_submitted':
      return 'تم إرسال الإيصال';
    case 'active':
      return 'فعّال';
    case 'inactive':
      return 'غير فعّال';
    case 'submitted':
      return 'تم الإرسال';
    case 'pending':
      return 'قيد المراجعة';
    case 'remitted':
      return 'مُرسل';
    case 'delivered':
      return 'تم التسليم';
    case 'completed':
      return 'مكتمل';
    case 'cancelled':
      return 'ملغي';
    case 'open':
      return 'مفتوحة';
    case 'in_progress':
      return 'قيد المعالجة';
    case 'resolved':
      return 'تم الحل';
    case 'reassign':
      return 'إعادة';
    case 'awaiting_captain':
      return 'بانتظار الكابتن';
    case 'captain_assigned':
      return 'تم تعيين الكابتن';
    case 'en_route_pickup':
      return 'في الطريق للاستلام';
    case 'arrived_pickup':
      return 'وصل نقطة الاستلام';
    case 'picked_up':
      return 'تم استلام الطرد';
    case 'en_route_delivery':
      return 'في الطريق للتسليم';
    case 'arrived_dropoff':
      return 'وصل موقع التسليم';
    case 'payment_pending':
      return 'بانتظار الدفع';
    case 'verification_approved':
      return 'موثّق ومقبول';
    case 'verification_pending':
      return 'قيد المراجعة';
    case 'verification_rejected':
      return 'مرفوض';
    default:
      // Never expose raw snake_case / enum values to users.
      final cleaned = status.trim();
      return cleaned.isEmpty ? '-' : cleaned.replaceAll('_', ' ');
  }
}

/// Payment methods as readable Arabic names (values stay untouched).
String paymentMethodLabel(String method) {
  switch (method) {
    case 'jawwal_pay':
      return 'جوّال باي';
    case 'bop_palestine':
      return 'بنك فلسطين';
    case 'palpay':
      return 'بال باي';
    default:
      return method.isEmpty ? '-' : method;
  }
}

/// Captain transport types as readable Arabic names.
String transportTypeLabel(String type) {
  switch (type) {
    case 'car':
      return 'سيارة';
    case 'motorcycle':
      return 'دراجة نارية';
    case 'bicycle':
      return 'دراجة هوائية';
    case 'other':
      return 'أخرى';
    default:
      return type.isEmpty ? '-' : type;
  }
}

/// Locale codes as readable language names.
String localeLabel(String locale) {
  switch (locale) {
    case 'ar':
      return 'العربية';
    case 'en':
      return 'English';
    default:
      return locale.isEmpty ? '-' : locale;
  }
}
void snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? ATheme.danger : ATheme.primary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
