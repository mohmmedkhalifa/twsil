import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Live production API on Render.
const String liveApiBase = 'https://twsil-api.onrender.com';

/// Debug/dev hosts (used only when not in release mode).
String get defaultHost {
  if (!kReleaseMode) {
    if (kIsWeb) return 'http://localhost:4000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:4000'
        : 'http://localhost:4000';
  }
  return liveApiBase;
}

final String apiBaseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
).isNotEmpty
    ? const String.fromEnvironment('API_BASE_URL')
    : '$defaultHost/api';

final String socketBaseUrl = const String.fromEnvironment(
  'SOCKET_BASE_URL',
  defaultValue: '',
).isNotEmpty
    ? const String.fromEnvironment('SOCKET_BASE_URL')
    : defaultHost;

const subscriptionFee = 10;
const serviceFee = 1;

String imageUrl(String url) {
  if (url.startsWith('http')) return url;
  return Uri.parse(apiBaseUrl).origin + url;
}

String currency(int n) => '$n ₪';

Color statusColor(String status) {
  switch (status) {
    case 'approved':
    case 'active':
    case 'delivered':
    case 'completed':
      return const Color(0xFF16A34A);
    case 'under_review':
    case 'pending':
    case 'en_route_pickup':
    case 'en_route_delivery':
    case 'captain_assigned':
    case 'picked_up':
      return const Color(0xFFF59E0B);
    case 'rejected':
    case 'cancelled':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}

String paymentMethodLabel(String method) {
  switch (method) {
    case 'jawwal_pay':
      return 'جوّال باي';
    case 'bop_palestine':
      return 'بنك فلسطين';
    case 'palpay':
      return 'بال باي';
    default:
      return method;
  }
}