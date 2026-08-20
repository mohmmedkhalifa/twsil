import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import 'verification_screen.dart';
import 'subscription_screen.dart';

class CaptainDashboardScreen extends StatefulWidget {
  const CaptainDashboardScreen({super.key});

  @override
  State<CaptainDashboardScreen> createState() => _CaptainDashboardScreenState();
}

class _CaptainDashboardScreenState extends State<CaptainDashboardScreen> {
  bool _isAvailable = false;
  bool _savingAvailability = false;

  @override
  void initState() {
    super.initState();
    _initFromProfile();
  }

  void _initFromProfile() {
    final profile = context.read<AuthCubit>().state.captainProfile;
    if (profile != null) {
      setState(() {
        _isAvailable = profile.isAvailable;
      });
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    // Instantaneous optimistic update for 0-lag responsiveness
    final previousValue = _isAvailable;
    setState(() {
      _isAvailable = value;
      _savingAvailability = true;
    });

    try {
      await ApiClient.instance.patch('/captains/me', body: {
        'isAvailable': value,
      });

      if (mounted) {
        setState(() => _savingAvailability = false);
        context.read<AuthCubit>().refreshCaptainProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'أصبحت متاحاً للتوصيل الآن 🟢' : 'تم إيقاف التوفر 🔴'),
            backgroundColor: value ? AppColors.success : AppColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAvailable = previousValue;
          _savingAvailability = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final profile = state.captainProfile;
        final currentUser = state.user;
        final vApproved = profile?.verificationStatus == 'approved' || profile?.verificationStatus == 'verification_approved';

        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة التحكم بالكابتن'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () async {
                  await context.read<AuthCubit>().refreshCaptainProfile();
                  _initFromProfile();
                },
              ),
            ],
          ),
          body: profile == null
              ? const LoadingWidget()
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  children: [
                    _CaptainInfoCard(profile: profile, user: currentUser),
                    const SizedBox(height: AppSpacing.sm),

                    // Availability Toggle Card
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _isAvailable ? AppColors.success : AppColors.border,
                          width: _isAvailable ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isAvailable ? AppColors.success : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _isAvailable ? 'متاح لاستقبال طلبات التوصيل' : 'غير متاح حالياً',
                                  style: AppTypography.h2.copyWith(
                                    color: _isAvailable ? AppColors.success : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_savingAvailability)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Switch(
                                  value: _isAvailable,
                                  activeTrackColor: AppColors.success,
                                  onChanged: vApproved ? _toggleAvailability : null,
                                ),
                            ],
                          ),
                          if (!vApproved) ...[
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'يجب توثيق حسابك أولاً لتتمكن من تشغيل حالة التوفر.',
                              style: TextStyle(color: AppColors.danger, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quick Stats Row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'الطلبات المكتملة',
                              value: '${profile.totalDeliveries}',
                              icon: Icons.check_circle_outline,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              label: 'إجمالي الأرباح',
                              value: '${profile.totalEarnings.toStringAsFixed(0)} ₪',
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatBox(
                              label: 'التقييم',
                              value: profile.rating.toStringAsFixed(1),
                              icon: Icons.star_outline,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Verification Status Tile
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                      title: const Text('توثيق الهوية والوثائق'),
                      subtitle: Text('الحالة: ${profile.verificationStatus}'),
                      trailing: StatusChip.fromStatus(profile.verificationStatus),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const VerificationScreen()),
                        );
                      },
                    ),

                    // Subscription Status Tile
                    ListTile(
                      leading: const Icon(Icons.card_membership_outlined, color: AppColors.primary),
                      title: const Text('اشتراك الكابتن الشهري'),
                      subtitle: Text('الحالة: ${profile.subscriptionStatus}'),
                      trailing: StatusChip.fromStatus(profile.subscriptionStatus),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CaptainInfoCard extends StatelessWidget {
  final CaptainProfile profile;
  final User? user;

  const _CaptainInfoCard({required this.profile, required this.user});

  @override
  Widget build(BuildContext context) {
    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final initialLetter = firstName.isNotEmpty ? firstName[0] : 'ك';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              initialLetter,
              style: AppTypography.h1.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null ? '$firstName $lastName' : 'الكابتن',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: 2),
                Text(
                  'وسيلة النقل: ${profile.transportType == "motorcycle" ? "دراجة نارية 🏍️" : "سيارة 🚗"}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.h2),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}