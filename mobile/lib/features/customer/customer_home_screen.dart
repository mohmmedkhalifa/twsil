import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/status_labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import '../orders/orders_cubit.dart';
import '../orders/order_widgets.dart';
import '../orders/order_track_screen.dart';
import '../orders/create_order_screen.dart';
import '../chat/conversations_screen.dart';

import 'public_captain_profile_sheet.dart';
import '../../core/models.dart';

class CustomerHomeScreen extends StatefulWidget {
  final bool captainMode;
  const CustomerHomeScreen({super.key, this.captainMode = false});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _availableCaptains = [];
  bool _loadingCaptains = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!widget.captainMode) {
      // Live availability: captains go online/offline in realtime.
      SocketService.instance.on('captain:availability', (_) => _loadAvailableCaptains());
      SocketService.instance.on('captain:availability_updated', (_) => _loadAvailableCaptains());
      SocketService.instance.on('order:status', (_) {
        context.read<OrdersCubit>().loadMyOrders();
      });
    }
    Future.microtask(_load);
  }

  @override
  void dispose() {
    if (!widget.captainMode) {
      SocketService.instance.off('captain:availability');
      SocketService.instance.off('captain:availability_updated');
      SocketService.instance.off('order:status');
    }
    super.dispose();
  }

  Future<void> _load() async {
    final cubit = context.read<OrdersCubit>();
    await cubit.loadMyOrders();
    if (!widget.captainMode) {
      _loadAvailableCaptains();
    }
  }

  Future<void> _loadAvailableCaptains() async {
    setState(() => _loadingCaptains = true);
    try {
      final list = await ApiClient.instance.get('/captains/nearby') as List<dynamic>;
      if (mounted) {
        setState(() {
          _availableCaptains = list;
          _loadingCaptains = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCaptains = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCaptain = widget.captainMode;
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCaptain ? 'طلباتي الكابتن' : 'الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            tooltip: 'الرسائل',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConversationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            if (!isCaptain) ...[
              // Welcome Header Block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً، ${user?.firstName ?? "عزيزي العميل"} 👋',
                      style: AppTypography.h1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'أين تريد إرسال طردك اليوم؟',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'إنشاء طلب توصيل جديد',
                      icon: Icons.add,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Available Captains Nearby Section
              SectionHeader(
                title: 'كباتن متاحون بالقرب منك 🟢',
                actionTitle: '${_availableCaptains.length} متاح',
              ),
              if (_loadingCaptains)
                const SizedBox(
                  height: 70,
                  child: LoadingWidget(),
                )
              else if (_availableCaptains.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'لا يوجد كباتن متاحون حالياً بالقرب، يسعدنا استقبال طلبك وسيقوم الكابتن بقبوله فور تفرغه.',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _availableCaptains.length,
                    itemBuilder: (context, i) {
                      final capData = _availableCaptains[i] as Map<String, dynamic>;
                      final profile = PublicCaptainProfile.fromJson(capData);

                      return InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => PublicCaptainProfileSheet(
                              captain: profile,
                              onRequestSent: _load,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.successBg,
                                    child: Icon(Icons.directions_car, color: AppColors.success, size: 14),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      profile.fullName.isEmpty ? 'كابتن متاح' : profile.fullName,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '🚗 ${transportTypeLabel(profile.transportType)} | ⭐ ${profile.rating.toStringAsFixed(1)}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(),
              ),
            ],

            const SectionHeader(title: 'قائمة الطلبات'),

            BlocBuilder<OrdersCubit, OrdersState>(
              builder: (context, state) {
                if (state.loading && state.orders.isEmpty) {
                  return const SizedBox(height: 150, child: LoadingWidget());
                }
                if (state.orders.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد طلبات حالياً',
                    subtitle: isCaptain
                        ? 'ستظهر هنا جميع الطلبات التي قمت بقبولها'
                        : 'عندما تنشئ طلب توصيل جديد سيظهر هنا لمتابعته.',
                    actionLabel: isCaptain ? null : 'إنشاء طلب جديد',
                    onAction: isCaptain
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                            );
                          },
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.orders.length,
                  itemBuilder: (context, i) {
                    final order = state.orders[i];
                    return OrderCard(
                      order: order,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderTrackScreen(orderId: order.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}