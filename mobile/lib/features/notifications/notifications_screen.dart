import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/socket_service.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import '../captain/captain_request_detail_screen.dart';
import '../orders/chat_screen.dart';
import '../orders/order_track_screen.dart';

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
                            if (mounted) {
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
                                    orderId: copy.orderId,
                                    conversationId: copy.conversationId,
                                  );
                                }
                              });
                            }
                            _openNotificationTarget(n);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Navigates to the screen relevant to the notification content.
  /// Captains are taken to the open request itself (fetched through the
  /// captain-only available endpoint); both parties go to tracking/chat.
  Future<void> _openNotificationTarget(AppNotification n) async {
    final role = context.read<AuthCubit>().state.user?.role ?? 'customer';
    final isCaptain = role == 'captain';

    // Chat message -> open the conversation directly.
    if ((n.type.startsWith('chat') || n.type.startsWith('message')) &&
        n.conversationId != null &&
        n.orderId != null) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(orderId: n.orderId!, conversationId: n.conversationId),
      ));
      return;
    }

    if (n.orderId == null || n.orderId!.isEmpty) return;

    // A brand-new open request for captains: fetch it from the captain-only
    // pool endpoint so eligibility is still enforced by the backend.
    if (isCaptain &&
        (n.type == 'order:created' ||
            n.type == 'direct_request:new' ||
            n.type.startsWith('order:payment'))) {
      try {
        final json = await ApiClient.instance.get('/orders/available/${n.orderId}');
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              CaptainRequestDetailScreen(order: Order.fromJson(json as Map<String, dynamic>)),
        ));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يعد هذا الطلب متاحاً حالياً')),
        );
      }
      return;
    }

    // Otherwise, if the user participates in the order, the tracking
    // screen works for both roles.
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: n.orderId!)),
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