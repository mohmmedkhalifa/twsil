import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../orders/order_track_screen.dart';
import 'submit_offer_sheet.dart';

/// Full details of an AVAILABLE delivery request, shown to captains
/// before accepting. Built from the already-fetched available-order data,
/// so it never exposes private customer information and never hits the
/// party-only order-details endpoint (which returns "Not allowed"
/// for captains that have not been assigned yet).
class CaptainRequestDetailScreen extends StatefulWidget {
  final Order order;
  const CaptainRequestDetailScreen({super.key, required this.order});

  @override
  State<CaptainRequestDetailScreen> createState() =>
      _CaptainRequestDetailScreenState();
}

class _CaptainRequestDetailScreenState extends State<CaptainRequestDetailScreen> {
  bool _accepting = false;

  String get _createdAtText {
    final d = widget.order.createdAt;
    return DateFormat('yyyy/MM/dd - HH:mm').format(d);
  }

  Future<void> _openOfferSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubmitOfferSheet(
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        onOfferSubmitted: () {},
      ),
    );
  }

  Future<void> _acceptDirect() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ApiClient.instance.post('/orders/${widget.order.id}/accept');
      SocketService.instance.joinOrder(widget.order.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: widget.order.id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiClient.errorMessage(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل الطلب #${order.orderNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusChip.fromStatus(order.status),
                Text(_createdAtText, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.trip_origin, color: AppColors.primary),
                    title: const Text('نقطة الاستلام', style: AppTypography.bodyMedium),
                    subtitle: Text(
                      order.pickupAddress,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on, color: AppColors.danger),
                    title: const Text('نقطة التسليم', style: AppTypography.bodyMedium),
                    subtitle: Text(
                      order.dropoffAddress,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تفاصيل الطرد', style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(order.packageDescription, style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _chip(Icons.inventory_2_outlined, order.packageSizeText),
                      _chip(Icons.scale_outlined,
                          order.weightKg > 0 ? '${order.weightKg.toStringAsFixed(1)} كجم' : 'الوزن غير محدد'),
                      _chip(
                        Icons.social_distance,
                        order.distanceKm > 0 ? order.formattedDistance : 'المسافة غير محددة',
                      ),
                      if ((order.latestPayment?.amount ?? 0) > 0)
                        _chip(Icons.payments_outlined, 'رسوم الخدمة مدفوعة'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'قبول مباشر',
              icon: Icons.thumb_up_alt_outlined,
              isLoading: _accepting,
              onPressed: _acceptDirect,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'تقديم عرض سعر',
              icon: Icons.local_offer_outlined,
              onPressed: _openOfferSheet,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
