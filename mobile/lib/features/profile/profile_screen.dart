import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_screens.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'يرجى تعبئة جميع الحقول المطلوبة');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/complaints', body: {
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الشكوى، سيتم التواصل معك قريباً 🟢')),
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
      appBar: AppBar(title: const Text('تقديم شكوى أو اقتراح')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const Text('فريق الدعم والخدمة', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'إذا واجهتك أي مشكلة مع سائق أو طلب، اكتب تفاصيلها وسيقوم فريق الإدارة بمتابعتها فوراً.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'موضوع الشكوى',
            hint: 'مثال: تأخر السائق / مشكلة في الحساب',
            controller: _subjectController,
            prefixIcon: Icons.subject_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'تفاصيل الشكوى',
            hint: 'اكتب الشكوى بالتفصيل...',
            controller: _descriptionController,
            maxLines: 4,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ErrorStateWidget(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'إرسال الشكوى',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        if (user == null) {
          return const SizedBox.shrink();
        }
        final isCaptain = user.role == 'captain';

        return Scaffold(
          appBar: AppBar(title: const Text('الملف الشخصي')),
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: const Icon(Icons.person, size: 30, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: AppTypography.h2,
                          ),
                          const SizedBox(height: 2),
                          Text(user.phone, style: AppTypography.caption),
                          const SizedBox(height: AppSpacing.xs),
                          StatusChip(
                            label: isCaptain ? 'سائق توصيل 🚚' : 'عميل 👤',
                            color: AppColors.primary,
                            backgroundColor: AppColors.primaryLight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.report_problem_outlined, color: AppColors.textSecondary),
                      title: const Text('تقديم شكوى أو اقتراح', style: AppTypography.bodyMedium),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.danger),
                      title: Text(
                        'تسجيل الخروج',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تسجيل الخروج'),
                            content: const Text('هل أنت متأكد من تسجيل الخروج من تطبيق توصيل؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await cubit.logout();
                                  if (context.mounted) {
                                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Text('تسجيل الخروج'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}