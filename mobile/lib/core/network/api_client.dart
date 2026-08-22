import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Single source of truth: the NestJS backend.
/// No Supabase fallback — the backend owns the database, realtime and FCM.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  final http.Client _client = http.Client();

  String? _token;
  User? user;

  static const Duration _timeout = Duration(seconds: 15);

  String _cleanPath(String path) {
    var p = path.trim();
    if (p.startsWith('/api')) p = p.substring(4);
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        user = userFromJson(userJson);
      } catch (_) {}
    }
  }

  Future<void> saveAuth(String token, User user) async {
    _token = token;
    this.user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  String get token => _token ?? '';

  void applyToken(String token) => _token = token;

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

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      final cleanPath = _cleanPath(path);
      final uri = Uri.parse('$apiBaseUrl$cleanPath').replace(queryParameters: query);

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth && _token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

      final t = timeout ?? _timeout;

      http.Response res;
      switch (method.toUpperCase()) {
        case 'POST':
          res = await _send(() => _client.post(uri, headers: headers, body: jsonEncode(body ?? {})), t);
        case 'PATCH':
          res = await _send(() => _client.patch(uri, headers: headers, body: jsonEncode(body ?? {})), t);
        case 'DELETE':
          res = await _send(() => _client.delete(uri, headers: headers, body: jsonEncode(body ?? {})), t);
        default:
          res = await _send(() => _client.get(uri, headers: headers), t);
      }

      final decoded = _decodeText(res.body);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (cleanPath.startsWith('/auth/login') ||
            cleanPath.startsWith('/auth/register')) {
          if (decoded is Map && decoded['accessToken'] != null) {
            _token = decoded['accessToken'] as String;
            if (decoded['user'] != null) {
              user = User.fromJson(Map<String, dynamic>.from(decoded['user'] as Map));
              await saveAuth(_token!, user!);
            }
          }
        }
        return decoded;
      } else if (res.statusCode == 401) {
        if (auth) await logout();
        throw ApiException('انتهت الجلسة، يرجى تسجيل الدخول مجدداً', statusCode: 401);
      } else {
        throw ApiException(_errorMessage(res.statusCode, decoded), statusCode: res.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(errorMessage(e));
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function() run,
    Duration? timeout,
  ) {
    if (timeout == null) return run();
    return run().timeout(timeout);
  }

  static String _errorMessage(int statusCode, dynamic decoded) {
    String msg = 'خطأ في الخادم ($statusCode)';
    if (decoded is Map && decoded['message'] != null) {
      if (decoded['message'] is List) {
        msg = (decoded['message'] as List).join(', ');
      } else {
        msg = decoded['message'].toString();
      }
    } else if (decoded is Map && decoded['error'] != null) {
      msg = decoded['error'].toString();
    } else if (decoded is Map && decoded['msg'] != null) {
      msg = decoded['msg'].toString();
    }
    return msg;
  }

  static String normalizePhone(String input) {
    var s = input.trim();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return s;
  }

  Future<String> uploadImageBytes(Uint8List bytes, String filename, {String? mimeType, String? category, String? folder}) async {
    final rawName = filename.split('/').last;
    final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(rawName);
    final ext = extMatch != null ? extMatch.group(1)!.toLowerCase() : 'jpg';
    final resolvedMime = mimeType ?? lookupMimeType(filename) ?? 'image/jpeg';

    final uri = Uri.parse('$apiBaseUrl/upload/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
    });

    final targetFolder = folder ?? (category == 'receipts' ? 'receipts' : 'uploads');
    request.fields['folder'] = targetFolder;
    request.fields['category'] = targetFolder;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload.$ext',
        contentType: MediaType.parse(resolvedMime),
      ),
    );

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeText(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final url = decoded['url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
    throw ApiException(
      _errorMessage(res.statusCode, decoded),
      statusCode: res.statusCode,
    );
  }

  Future<String> uploadXFile(XFile xFile, {String? category, String? folder}) async {
    final bytes = await xFile.readAsBytes();
    return uploadImageBytes(bytes, xFile.name, mimeType: xFile.mimeType, category: category, folder: folder);
  }

  Future<String> uploadImage(String filePath, {String folder = 'uploads', String? category, String? captainId, XFile? xFile}) async {
    if (xFile != null) {
      return uploadXFile(xFile, category: category, folder: folder);
    }
    if (kIsWeb) {
      throw ApiException('يرجى اختيار صورة صالحة للرفع في المتصفح');
    }
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return uploadImageBytes(bytes, filePath, category: category, folder: folder);
  }

  static String imageUrl(String url) {
    if (url.isEmpty || url == 'null') return '';
    var clean = url.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    if (clean.startsWith('/')) clean = clean.substring(1);

    const supabaseBase = 'https://ymqtrsnikcicywxtfjsx.supabase.co/storage/v1/object/public/twsil-images';

    if (clean.startsWith('twsil-images/')) {
      return '$supabaseBase/${clean.substring(13)}';
    }

    if (clean.startsWith('uploads/') ||
        clean.startsWith('receipts/') ||
        clean.startsWith('identity/') ||
        clean.startsWith('licenses/')) {
      return '$supabaseBase/$clean';
    }

    return '$apiBaseUrl/$clean';
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      request('POST', path, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      request('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? body, Map<String, String>? query}) =>
      request('DELETE', path, body: body, query: query);

  Map<String, dynamic> withUser(Map<String, dynamic> json) => {
        ...json,
        'currentUserId': user?.id,
        'role': user?.role,
      };

  static String errorMessage(Object e) {
    if (e is ApiException) return e.message;
    final str = e.toString();
    if (str.contains('SocketException') ||
        str.contains('Failed host lookup') ||
        str.contains('ClientException')) {
      return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت';
    }
    if (str.contains('TimeoutException')) {
      return 'انتهت مهلة الاتصال بالخادم، يرجى المحاولة لاحقاً';
    }
    if (str.contains('Exception:')) {
      return str.replaceAll('Exception:', '').trim();
    }
    return 'حدث خطأ: $str';
  }
}
