import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';

class RateOrderSheet extends StatefulWidget {
  final String orderId;
  final bool isCustomer;
  const RateOrderSheet({super.key, required this.orderId, this.isCustomer = true});

  @override
  State<RateOrderSheet> createState() => _RateOrderSheetState();
}

class _RateOrderSheetState extends State<RateOrderSheet> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/orders/${widget.orderId}/rate', body: {
        'rating': _rating,
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiClient.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isCustomer ? 'تقييم تجربة الخدمة' : 'تقييم العميل',
            textAlign: TextAlign.center,
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                iconSize: 32,
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: i < _rating ? AppColors.warning : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'ملاحظات التقييم (اختياري)',
            controller: _comment,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            ErrorStateWidget(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'إرسال التقييم',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}