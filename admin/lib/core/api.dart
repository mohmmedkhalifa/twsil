import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Admin client for the Twsil NestJS backend.
/// Production default points to the live Render backend.
final String adminApiBase = const String.fromEnvironment(
  'ADMIN_API_URL',
  defaultValue: 'https://twsil-api.onrender.com/api',
);

class AApi {
  AApi._();
  static final AApi instance = AApi._();

  final http.Client _client = http.Client();
  final String _apiBase = adminApiBase;

  String? token;
  Map<String, dynamic>? user;
  String? adminId;

  static const Duration _timeout = Duration(seconds: 20);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('admin_token');
    final u = prefs.getString('admin_user');
    if (u != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(u));
        adminId = user?['id']?.toString();
      } catch (_) {}
    }
  }

  Future<void> saveAuth(String t, Map<String, dynamic> u) async {
    token = t;
    user = u;
    adminId = u['id']?.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', t);
    await prefs.setString('admin_user', jsonEncode(u));
  }

  Future<void> logout() async {
    token = null;
    user = null;
    adminId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_user');
  }

  // ------------------------------------------------------------- auth

  String normalizePhone(String input) {
    var s = input.trim();
    for (final pair in {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    }.entries) {
      s = s.replaceAll(pair.key, pair.value);
    }
    return s;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await _httpRequest(
      () => _client.post(
        Uri.parse('$_apiBase/auth/login'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'phone': normalizePhone(phone), 'password': password}),
      ),
      auth: false,
      timeout: null,
    );

    if (res is! Map) {
      throw ApiError('استجابة غير متوقعة من الخادم');
    }
    final body = Map<String, dynamic>.from(res);
    final t = body['accessToken'] as String?;
    if (t == null || t.isEmpty) {
      throw ApiError('لم يتم استلام رمز الدخول من الخادم');
    }
    final u = (body['user'] as Map?)?.cast<String, dynamic>() ?? {};
    if (u['role'] != 'admin') {
      throw ApiError('هذا الحساب ليس بحساب إداري');
    }
    await saveAuth(t, u);
    return u;
  }

  // ------------------------------------------------------------- dispatch

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      request('POST', path, body: body);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => request('DELETE', path);

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    try {
      final raw = await _dispatch(method, path, body: body, query: query, auth: auth);
      return _normalize(raw);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError('خطأ غير متوقع: $e');
    }
  }

  Future<dynamic> _dispatch(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    switch (path) {
      case '/admin/stats':
        return _httpGet('/admin/stats', query: query);

      case '/orders/admin/payments':
        return _payments();

      case '/admin/subscriptions':
        return _subscriptions();

      case '/admin/captains':
        return _captains();

      case '/admin/users':
        return _adminUsers(query?['role']);

      case '/orders/admin/list':
        return _orders(query?['status']);

      case '/complaints/admin/list':
        return _complaints();

      case '/admin/reviews':
        return _reviews();
    }

    final payReview = RegExp(r'^/orders/admin/payments/(.+)/review$').firstMatch(path);
    if (payReview != null) return _httpPost('/orders/admin/payments/${payReview.group(1)}/review', body ?? {});

    final subReview = RegExp(r'^/admin/subscriptions/(.+)/review$').firstMatch(path);
    if (subReview != null) return _httpPost('/admin/subscriptions/${subReview.group(1)}/review', body ?? {});

    final ver = RegExp(r'^/admin/captains/(.+)/verification$').firstMatch(path);
    if (ver != null) return _httpPost('/admin/captains/${ver.group(1)}/verification', body ?? {});

    final toggleCap = RegExp(r'^/admin/captains/(.+)/toggle-active$').firstMatch(path);
    if (toggleCap != null) return _httpPost('/admin/captains/${toggleCap.group(1)}/toggle-active', body ?? {});

    final ban = RegExp(r'^/admin/users/(.+)/toggle-ban$').firstMatch(path);
    if (ban != null) return _httpPost('/admin/users/${ban.group(1)}/toggle-ban', body ?? {});

    final complaint = RegExp(r'^/complaints/admin/(.+)$').firstMatch(path);
    if (complaint != null) return _httpPatch('/complaints/admin/${complaint.group(1)}', body ?? {});

    final hide = RegExp(r'^/admin/reviews/(.+)/toggle-hide$').firstMatch(path);
    if (hide != null) return _httpPost('/admin/reviews/${hide.group(1)}/toggle-hide', body ?? {});

    throw ApiError('مسار غير معروف: $path');
  }

  // ------------------------------------------------------------- http helpers

  static String _snip(String s) => s.length > 200 ? s.substring(0, 200) : s;

  static dynamic _decodeText(String body) {
    if (body.isEmpty) return null;
    var s = body.trim();
    if (s.startsWith('\uFEFF')) s = s.substring(1).trim();
    try {
      return jsonDecode(s);
    } catch (_) {
      final startBrace = s.indexOf('{');
      final startBracket = s.indexOf('[');
      int start = -1;
      if (startBrace != -1 && startBracket != -1) {
        start = startBrace < startBracket ? startBrace : startBracket;
      } else if (startBrace != -1) {
        start = startBrace;
      } else if (startBracket != -1) {
        start = startBracket;
      }
      if (start >= 0) {
        final sub = s.substring(start);
        try {
          return jsonDecode(sub);
        } catch (_) {}
      }
      return body;
    }
  }

  Future<dynamic> _httpRequest(
    Future<http.Response> Function() run, {
    bool auth = true,
    Duration? timeout = _timeout,
  }) async {
    try {
      final response = timeout == null ? await run() : await run().timeout(timeout);
      final decoded = _decodeText(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      String message = 'خطأ في الاتصال بالخادم (${response.statusCode})';
      if (decoded is Map) {
        final msg = decoded['message'];
        if (msg is List && msg.isNotEmpty) {
          message = msg.join(', ');
        } else if (msg is String) {
          message = msg;
        } else if (decoded['error_description'] is String) {
          message = decoded['error_description'] as String;
        } else if (decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } else if (decoded is String && decoded.isNotEmpty) {
        message = 'استجابة غير متوقعة (${response.statusCode}): ${_snip(decoded)}';
      }

      if (response.statusCode == 401 && auth) await logout();
      throw ApiError(message);
    } catch (e) {
      if (e is ApiError) rethrow;
      final str = e.toString();
      if (str.contains('TimeoutException')) {
        throw ApiError('انتهت مهلة الاتصال بالخادم، يرجى المحاولة لاحقاً');
      }
      throw ApiError('تعذر الاتصال بالخادم: $str');
    }
  }

  Map<String, String> _headers({bool write = false}) => {
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
        if (write) 'Content-Type': 'application/json',
      };

  Future<dynamic> _httpGet(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_apiBase$path').replace(queryParameters: {
      if (query != null) ...query,
    });
    return _httpRequest(() => _client.get(uri, headers: _headers()));
  }

  Future<dynamic> _httpPost(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$_apiBase$path');
    return _httpRequest(
      () => _client.post(uri, headers: _headers(write: true), body: jsonEncode(body)),
    );
  }

  Future<dynamic> _httpPatch(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$_apiBase$path');
    return _httpRequest(
      () => _client.patch(uri, headers: _headers(write: true), body: jsonEncode(body)),
    );
  }

  // ------------------------------------------------------------- queries (NestJS → screen shapes)

  Future<List<dynamic>> _payments() async {
    final res = await _httpGet('/admin/payments');
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final order = (m['order'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final cust = (order['customer'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{
        ...m,
        'method': m['paymentMethod'],
        'submittedAt': m['transferDate'] ?? m['createdAt'],
        'receiptImageUrl': m['receiptImageUrl'] ?? m['receipt_image_url'] ?? m['receiptUrl'] ?? m['imageUrl'],
        'order': <String, dynamic>{
          ...order,
          'customer': <String, dynamic>{
            'firstName': cust['firstName'] ?? '',
            'lastName': cust['lastName'] ?? '',
            'phone': cust['phone'] ?? '',
          },
        },
      };
    }).toList();
  }

  Future<List<dynamic>> _subscriptions() async {
    final res = await _httpGet('/admin/subscriptions');
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final cap = (m['captain'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      // Backend may include nested user profile directly
      final captainUser = cap['user'] is Map
          ? (cap['user'] as Map).map((k, v) => MapEntry(k.toString(), v))
          : cap;
      return <String, dynamic>{
        ...m,
        'duration': 'monthly',
        'startDate': m['createdAt'],
        'receiptImageUrl': m['receiptImageUrl'] ?? m['receipt_image_url'] ?? m['receiptUrl'] ?? m['imageUrl'],
        'captain': <String, dynamic>{
          'firstName': captainUser['firstName'] ?? '',
          'lastName': captainUser['lastName'] ?? '',
          'phone': captainUser['phone'] ?? '',
        },
      };
    }).toList();
  }

  Future<List<dynamic>> _captains() async {
    final res = await _httpGet('/admin/captains');
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final u = (m['user'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final vs = m['verificationStatus']?.toString() ?? '';
      final userPhone = u['phone']?.toString() ?? '';
      return <String, dynamic>{
        ...m,
        'user': <String, dynamic>{
          ...u,
          'id': m['userId'],
          'phone': userPhone,
        },
        'idCardUrl': m['nationalIdCardImageUrl'] ?? m['idCardUrl'] ?? m['idCardImageUrl'] ?? m['id_card_url'] ?? u['avatarUrl'],
        'licenseUrl': m['licenseImageUrl'] ?? m['licenseUrl'] ?? m['license_url'] ?? u['avatarUrl'],
        'receiptImageUrl': m['receiptImageUrl'] ?? m['receiptUrl'] ?? m['subscriptionReceiptUrl'] ?? '',
        'verificationStatus': vs == 'approved'
            ? 'verification_approved'
            : vs == 'pending'
                ? 'verification_pending'
                : 'verification_rejected',
        'isActive': m['isActive'] == true,
      };
    }).toList();
  }

  Future<List<dynamic>> _orders(String? status) async {
    final res = await _httpGet('/admin/orders', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final customer = (m['customer'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final captain = (m['captain'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final pay = (m['payments'] as List? ?? []);
      return <String, dynamic>{
        ...m,
        'description': m['packageDescription'],
        'packageType': m['packageSize'],
        'paymentMethod': pay.isNotEmpty ? (pay.first as Map)['paymentMethod'] : (m['paymentMethod'] ?? ''),
        'receiptImageUrl': pay.isNotEmpty ? (pay.first as Map? ?? {})['receiptImageUrl'] : null,
        'payments': pay,
        'customer': <String, dynamic>{
          'firstName': customer['firstName'] ?? '',
          'lastName': customer['lastName'] ?? '',
          'phone': customer['phone'] ?? '',
        },
        'captain': <String, dynamic>{
          'user': <String, dynamic>{
            'firstName': captain['firstName'] ?? '',
            'lastName': captain['lastName'] ?? '',
            'phone': captain['phone'] ?? '',
          },
        },
      };
    }).toList();
  }

  Future<List<dynamic>> _adminUsers(String? role) async {
    final res = await _httpGet('/admin/users', query: {
      if (role != null && role.isNotEmpty && role != 'all') 'role': role,
    });
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{
        ...m,
        'phone': m['phone']?.toString() ?? '',
      };
    }).toList();
  }

  Future<List<dynamic>> _complaints() async {
    final res = await _httpGet('/complaints/admin/list');
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final user = (m['reporter'] as Map? ?? m['user'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final order = (m['order'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{
        ...m,
        'message': m['description'] ?? m['subject'] ?? '',
        'adminNote': m['resolutionNote'],
        'user': <String, dynamic>{
          'firstName': user['firstName'] ?? '',
          'lastName': user['lastName'] ?? '',
        },
        'order': <String, dynamic>{
          'orderNumber': order['orderNumber'] ?? '',
        },
      };
    }).toList();
  }

  Future<List<dynamic>> _reviews() async {
    final res = await _httpGet('/admin/reviews');
    if (res is! List) return [];
    return res.map((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final author = (m['reviewer'] as Map? ?? m['author'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      final order = (m['order'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{
        ...m,
        'isHidden': m['isHidden'] == true,
        'author': <String, dynamic>{
          'firstName': author['firstName'] ?? '',
          'lastName': author['lastName'] ?? '',
        },
        'order': <String, dynamic>{
          'orderNumber': order['orderNumber'] ?? '',
        },
      };
    }).toList();
  }

  // ------------------------------------------------------------- misc

  String imageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = Uri.parse(_apiBase).origin;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  Future<void> seedDemoData() async {
    throw ApiError('البيانات التجريبية تُنشأ عبر الخادم: npm run seed في مجلد backend');
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

String ae(Object e) => e is ApiError ? e.message : 'حدث خطأ غير متوقع (${e.runtimeType}: $e)';

dynamic _normalize(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.from(
      data.map((k, v) => MapEntry(k.toString(), _normalize(v))),
    );
  }
  if (data is List) return data.map(_normalize).toList();
  return data;
}