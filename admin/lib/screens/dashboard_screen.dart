import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'payment_center.dart';
import 'captains_screen.dart';
import 'orders_screen.dart';
import 'users_screen.dart';
import 'complaints_screen.dart';
import 'reviews_screen.dart';
import 'dash_stats.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  static const _titles = [
    'لوحة المعلومات',
    'مركز الدفع',
    'الطلبات',
    'السائقون والتوثيق',
    'المستخدمون',
    'الشكاوى',
    'التقييمات',
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final user = AApi.instance.user;

    final body = switch (_index) {
      0 => StatsPage(onSelectTab: (i) => setState(() => _index = i)),
      1 => const PaymentCenter(),
      2 => const OrdersPage(),
      3 => const CaptainsPage(),
      4 => const UsersPage(),
      5 => const ComplaintsPage(),
      _ => const ReviewsPage(),
    };

    return Scaffold(
      body: wide ? _wideLayout(body, user) : _narrowLayout(body, user),
    );
  }

  Widget _wideLayout(Widget body, Map<String, dynamic>? user) {
    return Row(
      children: [
        Material(
          color: const Color(0xFF123F2E),
          child: SafeArea(
            child: SizedBox(
              width: 230,
              child: Column(
                children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.white, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'توصيل - إدارة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                for (int i = 0; i < _destinations.length; i++)
                  _SideItem(
                    icon: _destinations[i].icon,
                    label: _destinations[i].label,
                    selected: _index == i,
                    onTap: () => setState(() => _index = i),
                  ),
                const Spacer(),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: Text(
                    'خروج (${user?['firstName'] ?? ''})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  onTap: () async {
                    await AApi.instance.logout();
                    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            ),
          ),
        ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _narrowLayout(Widget body, Map<String, dynamic>? user) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'توصيل - إدارة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (int i = 0; i < _destinations.length; i++)
                ListTile(
                  leading: Icon(_destinations[i].icon),
                  title: Text(_destinations[i].label),
                  selected: _index == i,
                  onTap: () {
                    setState(() => _index = i);
                    Navigator.of(context).pop();
                  },
                ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: ATheme.danger),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await AApi.instance.logout();
                  if (mounted) Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SideItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _destinations = [
  (icon: Icons.dashboard_outlined, label: 'لوحة المعلومات'),
  (icon: Icons.payments_outlined, label: 'مركز الدفع'),
  (icon: Icons.delivery_dining_outlined, label: 'الطلبات'),
  (icon: Icons.verified_user_outlined, label: 'السائقون والتوثيق'),
  (icon: Icons.people_outline, label: 'المستخدمون'),
  (icon: Icons.report_problem_outlined, label: 'الشكاوى'),
  (icon: Icons.star_outline, label: 'التقييمات'),
];