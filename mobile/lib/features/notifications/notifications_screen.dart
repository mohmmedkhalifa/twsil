import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/socket_service.dart';
import '../../core/widgets/ui_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SocketService.instance.on('notification', (_) => _load());
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiClient.instance.get('/notifications') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _notifications = json
            .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: _loading
          ? const LoadingWidget()
          : _notifications.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.notifications_none,
                  title: 'لا توجد إشعارات حالياً',
                  subtitle: 'ستظهر جميع الإشعارات وتحديثات الطلبات هنا',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: n.isRead ? AppColors.surface : AppColors.primaryLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: n.isRead ? AppColors.greyStatusBg : AppColors.primaryLight,
                            child: Icon(
                              _iconFor(n.type),
                              size: 20,
                              color: n.isRead ? AppColors.textMuted : AppColors.primary,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                          trailing: Text(
                            _timeAgo(n.createdAt),
                            style: AppTypography.caption,
                          ),
                          onTap: () async {
                            await ApiClient.instance.patch('/notifications/${n.id}/read');
                            setState(() {
                              final idx = _notifications.indexWhere((x) => x.id == n.id);
                              if (idx >= 0) {
                                final copy = _notifications[idx];
                                _notifications[idx] = AppNotification(
                                  id: copy.id,
                                  type: copy.type,
                                  title: copy.title,
                                  body: copy.body,
                                  isRead: true,
                                  createdAt: copy.createdAt,
                                );
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _iconFor(String type) {
    if (type.startsWith('order')) return Icons.local_shipping_outlined;
    if (type.startsWith('subscription')) return Icons.workspace_premium_outlined;
    if (type.startsWith('payment')) return Icons.payments_outlined;
    if (type.startsWith('chat')) return Icons.chat_bubble_outline;
    if (type.startsWith('complaint')) return Icons.report_problem_outlined;
    if (type.startsWith('captain')) return Icons.verified_user_outlined;
    if (type.startsWith('account')) return Icons.person_outline;
    return Icons.notifications_outlined;
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return '${diff.inMinutes} د';
    if (diff.inDays < 1) return '${diff.inHours} س';
    return '${d.day}/${d.month}/${d.year}';
  }
}