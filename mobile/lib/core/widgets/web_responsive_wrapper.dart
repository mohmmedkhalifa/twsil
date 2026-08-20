import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WebResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const WebResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Only wrap on Web when screen width is larger than mobile (width > 650)
    final media = MediaQuery.of(context);
    final isDesktopOrTablet = media.size.width > 650;

    if (!isDesktopOrTablet) {
      return child;
    }

    final isWideDesktop = media.size.width >= 1080;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek dark slate
      body: Stack(
        children: [
          // Background ambient light gradients
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Main Layout Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left/Right Branding Banner (For Wide Desktop Displays)
                    if (isWideDesktop) ...[
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App Logo Badge
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 32),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'توصيل',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              const Text(
                                'منصة التوصيل المباشر والتفاوض اللحظي 🛵',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'تطبيق توصيل تفاعلي يربطك مباشرة بالسائقين القريبين منك، يتيح تقديم العروض والتفاوض الفوري على أسعار التوصيل.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // Feature Highlights List
                              _buildFeatureTile(
                                icon: Icons.radar_rounded,
                                title: 'تكتشف الكباتن بالقرب منك',
                                subtitle: 'بحث جغرافي فوري للكباتن المتاحين',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildFeatureTile(
                                icon: Icons.local_offer_rounded,
                                title: 'تقديم وقبول العروض',
                                subtitle: 'عروض أسعار شفافة وتفاوض مباشر',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildFeatureTile(
                                icon: Icons.chat_rounded,
                                title: 'محادثة وتتبع حي',
                                subtitle: 'تتبع الخريطة والمحادثة الفورية للطلب',
                              ),

                              const SizedBox(height: AppSpacing.xxl),

                              // Web Badge tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language_rounded, color: AppColors.primary, size: 18),
                                    SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'تطبيق الويب الرسمي | twsil-app.web.app',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxl),
                    ],

                    // Phone Container Canvas
                    Container(
                      width: 480,
                      height: media.size.height > 920 ? 880 : media.size.height - 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 8,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Top phone status bar mockup
                          Container(
                            height: 28,
                            color: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'توصيل Web',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  width: 60,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.7), size: 12),
                                    const SizedBox(width: 4),
                                    Icon(Icons.battery_full, color: Colors.white.withValues(alpha: 0.7), size: 12),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Main Mobile App Canvas
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
