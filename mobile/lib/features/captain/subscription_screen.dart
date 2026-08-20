import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/ui_components.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Subscription> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await ApiClient.instance.get('/captains/subscriptions') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _history = json.map((s) => Subscription.fromJson(s as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اشتراك الكابتن الشهري')),
      body: _loading
          ? const LoadingWidget()
          : ListView(
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'رسوم الاشتراك الشهري',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$subscriptionFee ₪ / شهرياً',
                        style: AppTypography.h1.copyWith(
                          fontSize: 26,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'اشتراك رمزي يمكنك من استقبال وإنجاز عدد لا محدود من الطلبات.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'دفع الاشتراك ورفع الإيصال',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const _PaySubscriptionScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'سجل الاشتراكات السابقة'),
                const SizedBox(height: AppSpacing.xs),
                if (_history.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'لا توجد اشتراكات سابقة',
                    subtitle: 'جميع اشتراكاتك وإيصالاتك المدفوعة ستظهر هنا.',
                  )
                else
                  for (final sub in _history)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: StatusChip.fromStatus(sub.status),
                        title: Text(
                          '${sub.amount.toStringAsFixed(0)} ₪ عبر ${paymentMethodLabel(sub.paymentMethod)}',
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          sub.transactionNumber != null
                              ? 'رقم المعاملة: ${sub.transactionNumber}'
                              : (sub.adminNote ?? 'في انتظار مراجعة الإدارة'),
                          style: AppTypography.caption,
                        ),
                        trailing: sub.receiptImageUrl != null
                            ? IconButton(
                                icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Image.network(
                                      imageUrl(sub.receiptImageUrl!),
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(height: 200, child: Center(child: Icon(Icons.image))),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
              ],
            ),
    );
  }
}

class _PaySubscriptionScreen extends StatefulWidget {
  const _PaySubscriptionScreen();
  @override
  State<_PaySubscriptionScreen> createState() => _PaySubscriptionScreenState();
}

class _PaySubscriptionScreenState extends State<_PaySubscriptionScreen> {
  String _method = 'jawwal_pay';
  String? _receiptUrl;
  final _txnController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_receiptUrl == null) {
      setState(() => _error = 'يرجى رفع صورة الإيصال أولاً');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/captains/subscriptions', body: {
        'amount': subscriptionFee,
        'paymentMethod': _method,
        'receiptImageUrl': _receiptUrl,
        'transactionNumber': _txnController.text.trim().isEmpty
            ? null
            : _txnController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال إيصال الاشتراك للمراجعة 🟢')),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('دفع الاشتراك الشهري')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const Text('طريقة التحويل والدفع', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'قم بتحويل مبلغ $subscriptionFee شيكل إلى أحد حساباتنا وارفع صورة الإيصال ليتم تفعيل حسابك مباشرة:',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'jawwal_pay', label: Text('جوّال باي')),
              ButtonSegment(value: 'bank_palestine', label: Text('بنك فلسطين')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('صورة إيصال التحويل *', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          ReceiptUploader(onUploaded: (url) => setState(() => _receiptUrl = url)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'رقم المعاملة (اختياري)',
            hint: 'أدخل رقم المعاملة أو الإيصال',
            controller: _txnController,
            prefixIcon: Icons.confirmation_number_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ErrorStateWidget(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'إرسال الإيصال للتأكيد',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class ReceiptUploader extends StatefulWidget {
  final ValueChanged<String> onUploaded;
  const ReceiptUploader({super.key, required this.onUploaded});

  @override
  State<ReceiptUploader> createState() => _ReceiptUploaderState();
}

class _ReceiptUploaderState extends State<ReceiptUploader> {
  String? _url;
  bool _uploading = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ApiClient.instance.uploadImage(picked.path, category: 'receipts');
      if (!mounted) return;
      setState(() {
        _url = url;
        _uploading = false;
      });
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _uploading ? null : _pick,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _url != null ? AppColors.primary : AppColors.border,
            width: _url != null ? 1.5 : 1,
          ),
          color: AppColors.surface,
        ),
        child: _uploading
            ? const LoadingWidget()
            : _url != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                    child: Image.network(_url!, fit: BoxFit.cover, width: double.infinity),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textMuted),
                      SizedBox(height: AppSpacing.xs),
                      Text('اضغط هنا لرفع صورة الإيصال', style: AppTypography.caption),
                    ],
                  ),
      ),
    );
  }
}