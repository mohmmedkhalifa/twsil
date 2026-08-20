import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_client.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {}

class PushService {
  static bool _ready = false;
  static FirebaseMessaging? _messaging;

  /// Safe to call anytime; silently no-ops if Firebase isn't configured yet.
  static Future<void> init() async {
    try {
      if (!_ready) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _ready = true;
      }
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      if (!kIsWeb) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
        messaging.onTokenRefresh.listen((_) => sync());
      }

      await sync();

      FirebaseMessaging.onMessage.listen((message) {
        if (ApiClient.instance.user?.role == 'captain') {
          // keep captain order lists fresh on foreground push
          // (in-app updates still arrive via socket while connected)
        }
      });
    } catch (_) {
      // Firebase not configured yet on this platform - app continues normally.
    }
  }

  /// Registers the current device token with the backend (if logged in).
  static Future<void> sync() async {
    try {
      if (!_ready || !ApiClient.instance.isLoggedIn) return;
      final token = await _messaging?.getToken();
      if (token == null || token.isEmpty) return;
      await ApiClient.instance.post('/auth/fcm-token', body: {'token': token});
    } catch (_) {}
  }
}