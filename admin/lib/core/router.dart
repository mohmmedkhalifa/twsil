import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'theme.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/dash_stats.dart';
import '../screens/users_screen.dart';
import '../screens/user_detail_screen.dart';
import '../screens/captains_screen.dart';
import '../screens/captain_detail_screen.dart';
import '../screens/admins_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/payment_center.dart';
import '../screens/complaints_screen.dart';
import '../screens/reviews_screen.dart';

/// Real URL routing for the admin dashboard.
///
/// Every page has its own path, deep links open directly, refresh keeps the
/// page, and the browser Back/Forward buttons work through the history API.
final GoRouter router = GoRouter(
  initialLocation: '/admin/dashboard',
  redirect: (context, state) {
    final loggedIn = AApi.instance.token != null;
    final goingToLogin = state.matchedLocation == '/login';
    if (!loggedIn && !goingToLogin) return '/login';
    if (loggedIn && goingToLogin) return '/admin/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/admin/dashboard', builder: (_, __) => const StatsPage()),
        GoRoute(path: '/admin/payments', builder: (_, __) => const PaymentCenter()),
        GoRoute(
          path: '/admin/orders',
          builder: (_, __) => const OrdersPage(),
          routes: [
            GoRoute(path: ':id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
          ],
        ),
        GoRoute(
          path: '/admin/captains',
          builder: (_, __) => const CaptainsPage(),
          routes: [
            GoRoute(path: ':id', builder: (_, s) => CaptainDetailScreen(captainUserId: s.pathParameters['id']!)),
          ],
        ),
        GoRoute(
          path: '/admin/users',
          builder: (_, __) => const UsersPage(),
          routes: [
            GoRoute(path: ':id', builder: (_, s) => UserDetailScreen(userId: s.pathParameters['id']!)),
          ],
        ),
        GoRoute(path: '/admin/admins', builder: (_, __) => const AdminsPage()),
        GoRoute(path: '/admin/complaints', builder: (_, __) => const ComplaintsPage()),
        GoRoute(path: '/admin/reviews', builder: (_, __) => const ReviewsPage()),
      ],
    ),
  ],
);

/// Breadcrumbs built from the current location.
/// e.g. /admin/users/<id> → Dashboard > المستخدمون > تفاصيل المستخدم
class Breadcrumbs extends StatelessWidget {
  final String location;
  const Breadcrumbs({super.key, required this.location});

  static const _labels = {
    'dashboard': 'لوحة المعلومات',
    'payments': 'مركز الدفع',
    'orders': 'الطلبات',
    'captains': 'السائقون والتوثيق',
    'users': 'المستخدمون',
    'admins': 'المدراء',
    'complaints': 'الشكاوى',
    'reviews': 'التقييمات',
  };

  @override
  Widget build(BuildContext context) {
    final segments =
        location.split('/').where((s) => s.isNotEmpty && s != 'admin').toList();
    final crumbs = <Widget>[
      InkWell(
        onTap: () => context.go('/admin/dashboard'),
        child: const Text(
          'لوحة المعلومات',
          style: TextStyle(fontSize: 12.5, color: Colors.grey),
        ),
      ),
    ];
    var path = '/admin';
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      path += '/$seg';
      final isLast = i == segments.length - 1;
      String label;
      if (i == segments.length - 1 && segments.length > 1 && !isSegmentNamed(seg)) {
        label = isUuid(seg) ? 'تفاصيل' : Uri.decodeComponent(seg);
      } else {
        label = _labels[seg] ?? seg;
      }
      crumbs.addAll([
        const Text('  ›  ', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
        if (!isLast)
          InkWell(
            onTap: () => context.go(_listPath(path)),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: ATheme.primary, fontWeight: FontWeight.w600),
            ),
          )
        else
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: crumbs),
      ),
    );
  }

  static bool isSegmentNamed(String seg) => _labels.containsKey(seg);
  static bool isUuid(String s) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);

  String _listPath(String detailPath) {
    final parts = detailPath.split('/').toList()..removeLast();
    return parts.join('/');
  }
}
