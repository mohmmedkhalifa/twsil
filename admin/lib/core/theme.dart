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
      return 'تم الإرسال';
    case 'active':
      return 'فعّال';
    case 'inactive':
      return 'غير فعّال';
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
      return 'بانتظار سائق';
    case 'captain_assigned':
      return 'سائق معيّن';
    case 'en_route_pickup':
      return 'في الطريق للاستلام';
    case 'arrived_pickup':
      return 'وصل للاستلام';
    case 'picked_up':
      return 'تم الاستلام';
    case 'en_route_delivery':
      return 'في الطريق للتسليم';
    case 'arrived_dropoff':
      return 'وصل للتسليم';
    case 'payment_pending':
      return 'بانتظار الدفع';
    default:
      return status;
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
