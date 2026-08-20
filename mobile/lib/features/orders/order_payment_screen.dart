import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../captain/subscription_screen.dart';
import 'order_track_screen.dart';

class OrderPaymentScreen extends StatefulWidget {
  final Order order;
  const OrderPaymentScreen({super.key, required this.order});

  @override
  State<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends State<OrderPaymentScreen> {
  String _method = 'jawwal_pay';
  String? _receiptUrl;
  final _txnController = TextEditingController();
  bool _loading = false;
  String? _error;

  double get _fee => widget.order.serviceFee > 0 ? widget.order.serviceFee : 1.0;

  Future<void> _submit() async {
    if (_receiptUrl == null) {
      setState(() => _error = 'يرجى رفع صورة الإيصال أولاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/orders/${widget.order.id}/payments', body: {
        'amount': _fee,
        'paymentMethod': _method,
        'receiptImageUrl': _receiptUrl,
        'transactionNumber': _txnController.text.trim().isEmpty
            ? null
            : _txnController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderTrackScreen(orderId: widget.order.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feeInt = _fee.toInt();
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد دفع رسوم الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب #${widget.order.orderNumber}',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المسافة المقدرة:', style: AppTypography.bodyMedium),
                    Text(
                      widget.order.formattedDistance,
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رسوم الخدمة:', style: AppTypography.bodyMedium),
                    Text(
                      '$feeInt ₪',
                      style: AppTypography.h2.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('أجرة التوصيل (تُدفع للكابتن):', style: AppTypography.caption),
                    Text(
                      widget.order.deliveryFee > 0
                          ? '${widget.order.deliveryFee.toInt()} ₪'
                          : 'يحددها الكابتن',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'طريقة دفع رسوم الخدمة',
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'قم بتحويل $feeInt شيكل عبر أحد خيارات الدفع أدناه وارفع صورة الإيصال لتأكيد الطلب:',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'jawwal_pay', label: Text('جوّال باي')),
              ButtonSegment(value: 'bank_palestine', label: Text('بنك فلسطين')),
              ButtonSegment(value: 'cash', label: Text('كاش')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('صورة إيصال التحويل', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          ReceiptUploader(onUploaded: (url) => setState(() => _receiptUrl = url)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'رقم المعاملة (اختياري)',
            hint: 'أدخل رقم العملية أو الإيصال',
            controller: _txnController,
            prefixIcon: Icons.confirmation_number_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ErrorStateWidget(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'تأكيد وإرسال الطلب',
            isLoading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}