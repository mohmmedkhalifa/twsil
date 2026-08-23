import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String? _nationalIdImage;
  String? _licenseImage;
  bool _submitting = false;
  String? _error;

  Future<void> _pickImage(bool isId) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;
    try {
      final url = await ApiClient.instance.uploadXFile(
        picked,
        category: isId ? 'identity' : 'license',
        sub: isId ? 'front' : null,
      );
      if (!mounted) return;
      setState(() {
        if (isId) {
          _nationalIdImage = url;
        } else {
          _licenseImage = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _submit() async {
    if (_nationalIdImage == null) {
      setState(() => _error = 'صورة الهوية مطلوبة لتوثيق الحساب');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/captains/verification', body: {
        'nationalIdCardImageUrl': _nationalIdImage,
        'licenseImageUrl': _licenseImage,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الوثائق، بانتظار مراجعة وتفعيل الإدارة 🟢')),
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
      appBar: AppBar(title: const Text('توثيق هوية الكابتن')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const Text(
            'تعليمات توثيق الحساب',
            style: AppTypography.h2,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'أرفق صورة واضحة من بطاقة الهوية الوطنية وصورة الرخصة (إن وجدت). تقوم الإدارة بمراجعة البيانات خلال 24 ساعة لتفعيل توفرك للتوصيل.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('صورة بطاقة الهوية الوطنية *', style: AppTypography.bodyMedium),
              StatusChip(
                label: _nationalIdImage != null ? 'تم الرفع 🟢' : 'لم يتم الرفع 🔴',
                color: _nationalIdImage != null ? AppColors.success : AppColors.danger,
                backgroundColor: _nationalIdImage != null ? AppColors.successBg : AppColors.dangerBg,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _DocUploader(
            url: _nationalIdImage,
            label: 'اضغط هنا لرفع صورة بطاقة الهوية الوطنية',
            onTap: () => _pickImage(true),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('صورة رخصة القيادة (اختياري)', style: AppTypography.bodyMedium),
              StatusChip(
                label: _licenseImage != null ? 'تم الرفع 🟢' : 'اختياري',
                color: _licenseImage != null ? AppColors.success : AppColors.greyStatus,
                backgroundColor: _licenseImage != null ? AppColors.successBg : AppColors.greyStatusBg,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _DocUploader(
            url: _licenseImage,
            label: 'اضغط هنا لرفع صورة رخصة القيادة',
            onTap: () => _pickImage(false),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ErrorStateWidget(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'إرسال الوثائق للمراجعة',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _DocUploader extends StatelessWidget {
  final String? url;
  final String label;
  final VoidCallback onTap;
  const _DocUploader({required this.url, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: url != null ? AppColors.primary : AppColors.border,
            width: url != null ? 1.5 : 1,
          ),
          color: AppColors.surface,
        ),
        child: url != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                child: Image.network(url!, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: AppTypography.caption),
                ],
              ),
      ),
    );
  }
}