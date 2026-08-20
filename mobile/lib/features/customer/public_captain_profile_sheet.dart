import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/ui_components.dart';

class PublicCaptainProfileSheet extends StatefulWidget {
  final PublicCaptainProfile captain;
  final VoidCallback? onRequestSent;

  const PublicCaptainProfileSheet({
    super.key,
    required this.captain,
    this.onRequestSent,
  });

  @override
  State<PublicCaptainProfileSheet> createState() => _PublicCaptainProfileSheetState();
}

class _PublicCaptainProfileSheetState extends State<PublicCaptainProfileSheet> {
  bool _showRequestForm = false;
  bool _isSubmitting = false;

  final _itemController = TextEditingController();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _priceController = TextEditingController(text: '15');

  @override
  void dispose() {
    _itemController.dispose();
    _pickupController.dispose();
    _deliveryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submitDirectRequest() async {
    if (_itemController.text.trim().isEmpty ||
        _pickupController.text.trim().isEmpty ||
        _deliveryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوب')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final price = double.tryParse(_priceController.text) ?? 15.0;
      await ApiClient.instance.post('/captains/${widget.captain.userId}/direct-request', body: {
        'itemDescription': _itemController.text.trim(),
        'pickupAddress': _pickupController.text.trim(),
        'deliveryAddress': _deliveryController.text.trim(),
        'offeredPrice': price,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب التوصيل المباشر إلى الكابتن بنجاح!'),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onRequestSent?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الطلب: ${ApiClient.errorMessage(e)}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.captain;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Profile Header
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: c.avatarUrl != null ? NetworkImage(c.avatarUrl!) : null,
                  child: c.avatarUrl == null
                      ? Text(
                          c.firstName.isNotEmpty ? c.firstName[0] : 'ك',
                          style: AppTypography.h1.copyWith(color: AppColors.primary),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName.isNotEmpty ? c.fullName : 'كابتن توصيل',
                        style: AppTypography.h2,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            c.rating.toStringAsFixed(1),
                            style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '(${c.totalDeliveries} توصيلة)',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (c.distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${c.distanceKm} كم',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (c.bio != null && c.bio!.isNotEmpty) ...[
              Text(
                c.bio!,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            if (!_showRequestForm) ...[
              PrimaryButton(
                label: 'طلب توصيل مباشر',
                icon: Icons.send_rounded,
                onPressed: () => setState(() => _showRequestForm = true),
              ),
            ] else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'تفاصيل الطلب المباشر',
                    style: AppTypography.h2,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: _itemController,
                    label: 'وصف الغرض',
                    hint: 'مثال: وجبة طعام / وثائق / طرد',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: _pickupController,
                    label: 'عنوان الاستلام',
                    hint: 'مثال: حي الرمال - بالقرب من المخبز',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: _deliveryController,
                    label: 'عنوان التسليم',
                    hint: 'مثال: شارع النصر - بناء 12',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: _priceController,
                    label: 'السعر المعروض (₪)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'إلغاء',
                          onPressed: () => setState(() => _showRequestForm = false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: 'إرسال الطلب',
                          isLoading: _isSubmitting,
                          onPressed: _submitDirectRequest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
