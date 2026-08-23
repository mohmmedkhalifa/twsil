import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/router.dart';
import '../core/theme.dart';

class AdminShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AdminShell({super.key, required this.location, required this.child});

  static const _destinations = [
    (path: '/admin/dashboard', icon: Icons.dashboard_outlined, label: 'لوحة المعلومات'),
    (path: '/admin/payments', icon: Icons.payments_outlined, label: 'مركز الدفع'),
    (path: '/admin/orders', icon: Icons.delivery_dining_outlined, label: 'الطلبات'),
    (path: '/admin/captains', icon: Icons.verified_user_outlined, label: 'السائقون والتوثيق'),
    (path: '/admin/users', icon: Icons.people_outline, label: 'المستخدمون'),
    (path: '/admin/admins', icon: Icons.admin_panel_settings_outlined, label: 'المدراء'),
    (path: '/admin/complaints', icon: Icons.report_problem_outlined, label: 'الشكاوى'),
    (path: '/admin/reviews', icon: Icons.star_outline, label: 'التقييمات'),
  ];

  String get _title {
    for (final d in _destinations) {
      if (_isSelected(d.path, location)) return d.label;
    }
    return 'لوحة المعلومات';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final user = AApi.instance.user;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Breadcrumbs(location: location),
        Expanded(child: child),
      ],
    );
    return Scaffold(
      body: wide ? _wideLayout(context, body, user) : _narrowLayout(context, body, user),
    );
  }

  bool _isSelected(String destPath, String loc) =>
      loc == destPath || loc.startsWith('$destPath/');

  Widget _wideLayout(BuildContext context, Widget body, Map<String, dynamic>? user) {
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
                  Expanded(
                    child: ListView(
                      children: [
                        for (final d in _destinations)
                          _SideItem(
                            icon: d.icon,
                            label: d.label,
                            selected: _isSelected(d.path, location),
                            onTap: () => router.go(d.path),
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white70),
                    title: Text(
                      'خروج (${user?['firstName'] ?? ''})',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    onTap: () async {
                      await AApi.instance.logout();
                      router.go("/login");
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

  Widget _narrowLayout(BuildContext context, Widget body, Map<String, dynamic>? user) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
              Expanded(
                child: ListView(
                  children: [
                    for (final d in _destinations)
                      ListTile(
                        leading: Icon(d.icon),
                        title: Text(d.label),
                        selected: _isSelected(d.path, location),
                        onTap: () {
                          final nav = Navigator.of(context);
                          router.go(d.path);
                          nav.pop();
                        },
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: ATheme.danger),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await AApi.instance.logout();
                  router.go("/login");
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
