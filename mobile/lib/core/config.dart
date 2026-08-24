import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'status_labels.dart' as sl;

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

Color statusColor(String status) => sl.statusColorFor(status);

String paymentMethodLabel(String method) => sl.paymentMethodLabel(method);