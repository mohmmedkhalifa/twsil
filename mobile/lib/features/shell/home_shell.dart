import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_screens.dart';
import '../captain/available_orders_screen.dart';
import '../captain/captain_dashboard_screen.dart';
import '../customer/customer_home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../orders/orders_cubit.dart';
import '../orders/create_order_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit(),
      child: const _ShellBody(),
    );
  }
}

class _ShellBody extends StatefulWidget {
  const _ShellBody();
  @override
  State<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends State<_ShellBody> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final role = context.select((AuthCubit c) => c.state.user?.role) ?? 'customer';
    final isCaptain = role == 'captain';
    final pages = isCaptain
        ? const [
            CaptainDashboardScreen(),
            AvailableOrdersScreen(),
            CustomerHomeScreen(captainMode: true),
            NotificationsScreen(),
            ProfileScreen(),
          ]
        : const [
            CustomerHomeScreen(),
            HomeCreateOrderTab(),
            NotificationsScreen(),
            ProfileScreen(),
          ];

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => current.status == AuthStatus.unauthenticated,
      listener: (context, state) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: isCaptain
              ? const [
                  NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
                  NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'طلبات التوصيل'),
                  NavigationDestination(icon: Icon(Icons.assignment_turned_in_outlined), selectedIcon: Icon(Icons.assignment_turned_in), label: 'طلباتي'),
                  NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'إشعارات'),
                  NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
                ]
              : const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
                  NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'طلب جديد'),
                  NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'إشعارات'),
                  NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
                ],
        ),
      ),
    );
  }
}

class HomeCreateOrderTab extends StatelessWidget {
  const HomeCreateOrderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب توصيل جديد')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_location_alt_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('أرسل طردك بأمان مع توصيل', style: AppTypography.h1, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'حدد موقع الاستلام والتسليم واوصف طردك ليصل بلمح البصر.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'بدء إنشاء الطلب',
                icon: Icons.add,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}