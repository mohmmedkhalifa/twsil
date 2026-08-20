import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../orders/orders_cubit.dart';
import '../orders/order_widgets.dart';
import '../orders/order_track_screen.dart';

import 'submit_offer_sheet.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OrdersCubit>().loadAvailable();

    SocketService.instance.on('order:created', (data) {
      if (mounted) context.read<OrdersCubit>().loadAvailable();
    });
    SocketService.instance.on('order:status', (data) {
      if (mounted) context.read<OrdersCubit>().loadAvailable();
    });
    SocketService.instance.on('direct_request:new', (data) {
      if (mounted) context.read<OrdersCubit>().loadAvailable();
    });
    // A peer captain accepted/took the order (offer accepted or direct accept):
    // remove it from the pool for everyone.
    SocketService.instance.on('offer:accepted', (data) {
      if (mounted) context.read<OrdersCubit>().loadAvailable();
    });
    SocketService.instance.on('order:taken', (data) {
      if (mounted) context.read<OrdersCubit>().loadAvailable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المتاحة للتوصيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => context.read<OrdersCubit>().loadAvailable(),
          ),
        ],
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          if (state.loading && state.orders.isEmpty) {
            return const LoadingWidget();
          }
          if (state.orders.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.radar_outlined,
              title: 'لا توجد طلبات متاحة حالياً',
              subtitle: 'ستصلك الإشعارات والطلبات فور نشرها بالقرب منك.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<OrdersCubit>().loadAvailable(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: state.orders.length,
              itemBuilder: (context, i) {
                final order = state.orders[i];
                return Column(
                  children: [
                    OrderCard(
                      order: order,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderTrackScreen(orderId: order.id),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              icon: Icons.local_offer_outlined,
                              label: 'تقديم عرض',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => SubmitOfferSheet(
                                    orderId: order.id,
                                    orderNumber: order.orderNumber,
                                    onOfferSubmitted: () {
                                      context.read<OrdersCubit>().loadAvailable();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              icon: Icons.thumb_up_alt_outlined,
                              onPressed: () => _accept(context, order),
                              label: 'قبول مباشر',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _accept(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قبول الطلب'),
        content: Text(
          'تأكيد قبول الطلب #${order.orderNumber}؟\nالمسافة المقدرة: ${order.formattedDistance}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('قبول')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.post('/orders/${order.id}/accept');
      if (!context.mounted) return;
      context.read<OrdersCubit>().removeOrder(order.id);
      SocketService.instance.joinOrder(order.id);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderTrackScreen(orderId: order.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      context.read<OrdersCubit>().loadAvailable();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }
}