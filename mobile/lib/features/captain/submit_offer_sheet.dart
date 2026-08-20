import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/ui_components.dart';

class SubmitOfferSheet extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final VoidCallback? onOfferSubmitted;

  const SubmitOfferSheet({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.onOfferSubmitted,
  });

  @override
  State<SubmitOfferSheet> createState() => _SubmitOfferSheetState();
}

class _SubmitOfferSheetState extends State<SubmitOfferSheet> {
  final _priceController = TextEditingController(text: '20');
  final _etaController = TextEditingController(text: '30');
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _etaController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال السعر المقترح')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final price = double.tryParse(_priceController.text) ?? 20.0;
      final eta = int.tryParse(_etaController.text) ?? 30;

      await ApiClient.instance.post('/orders/${widget.orderId}/offers', body: {
        'price': price,
        'estimatedTimeMinutes': eta,
        'message': _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال عرض التوصيل للعميل بنجاح! 🚀'),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onOfferSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تقديم العرض: ${ApiClient.errorMessage(e)}'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'تقديم عرض توصيل 🏷️',
              style: AppTypography.h2,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'طلب رقم ${widget.orderNumber}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _priceController,
              label: 'أجرتك المقترحة بالتوصيل (₪)',
              hint: '20',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _etaController,
              label: 'الوقت المتوقع للوصول (بالدقائق)',
              hint: '30',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _messageController,
              label: 'ملاحظة أو رسالة للعميل (اختياري)',
              hint: 'مثال: أنا قريب جداً ومستعد للانطلاق فوراً',
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'إرسال العرض للعميل',
              icon: Icons.send_rounded,
              isLoading: _isSubmitting,
              onPressed: _submitOffer,
            ),
          ],
        ),
      ),
    );
  }
}
