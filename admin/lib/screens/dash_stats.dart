import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/polling.dart';

class StatsPage extends StatefulWidget {
  final Function(int index)? onSelectTab;
  const StatsPage({super.key, this.onSelectTab});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with PollingMixin {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    startPolling();
  }

  @override
  void onPoll() => _load();

  Future<void> _load() async {
    try {
      final s = await AApi.instance.get('/admin/stats') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلومات'),
        actions: [
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const Center(child: Text('تعذر تحميل الإحصائيات'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _StatCard(
                            icon: Icons.people,
                            color: const Color(0xFF2563EB),
                            label: 'إجمالي المستخدمين',
                            value: '${s['usersCount'] ?? 0}',
                            onTap: () => context.go('/admin/users'),
                          ),
                          _StatCard(
                            icon: Icons.verified_user,
                            color: const Color(0xFF7C3AED),
                            label: 'السائقون',
                            value: '${s['captainsCount'] ?? 0}',
                            onTap: () => context.go('/admin/captains'),
                          ),
                          _StatCard(
                            icon: Icons.person_outline,
                            color: const Color(0xFF0EA5E9),
                            label: 'العملاء',
                            value: '${s['customersCount'] ?? 0}',
                            onTap: () => context.go('/admin/users'),
                          ),
                          _StatCard(
                            icon: Icons.delivery_dining,
                            color: ATheme.primary,
                            label: 'طلبات نشطة',
                            value: '${s['activeOrdersCount'] ?? 0}',
                            onTap: () => context.go('/admin/orders'),
                          ),
                          _StatCard(
                            icon: Icons.pending_actions,
                            color: const Color(0xFFF59E0B),
                            label: 'توثيق بانتظار',
                            value: '${s['pendingVerification'] ?? 0}',
                            onTap: () => context.go('/admin/captains'),
                          ),
                          _StatCard(
                            icon: Icons.fact_check_outlined,
                            color: const Color(0xFFF97316),
                            label: 'اشتراكات للمراجعة',
                            value: '${s['pendingSubscriptions'] ?? 0}',
                            onTap: () => context.go('/admin/captains'),
                          ),
                          _StatCard(
                            icon: Icons.receipt_long,
                            color: const Color(0xFFEF4444),
                            label: 'إيصالات للمراجعة',
                            value: '${s['pendingPayments'] ?? 0}',
                            onTap: () => context.go('/admin/payments'),
                          ),
                          _StatCard(
                            icon: Icons.payments,
                            color: const Color(0xFF10B981),
                            label: 'إيرادات الاشتراكات',
                            value: '${s['subscriptionRevenue'] ?? 0} ₪',
                            onTap: () => context.go('/admin/payments'),
                          ),
                          _StatCard(
                            icon: Icons.savings_outlined,
                            color: const Color(0xFF6366F1),
                            label: 'إيرادات رسوم الخدمة',
                            value: '${s['serviceFeeRevenue'] ?? 0} ₪',
                            onTap: () => context.go('/admin/payments'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          child: Card(
            elevation: _isHovered ? 6 : 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isHovered ? widget.color.withValues(alpha: .5) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(widget.icon, color: widget.color, size: 22),
                        ),
                        if (widget.onTap != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: _isHovered ? widget.color : Colors.grey.withValues(alpha: .5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(widget.label, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}