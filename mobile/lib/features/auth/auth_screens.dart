import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_components.dart';
import '../auth/auth_cubit.dart';
import '../shell/home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<AuthCubit>().bootstrap();
    if (!mounted) return;
    final state = context.read<AuthCubit>().state;
    if (state.status == AuthStatus.authenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'توصيل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'منصة التوصيل البسيطة والمباشرة',
              style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 52),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'مرحباً بك في توصيل',
                textAlign: TextAlign.center,
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'أرسل طرودك وشحناتك بسهولة وسرعة مع أقرب سائق توصيل موثوق.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'تسجيل الدخول',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'إنشاء حساب جديد',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final phone = _phone.text.trim();
    final password = _password.text;
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف وكلمة المرور');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.read<AuthCubit>().login(phone, password);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = error;
    });

    if (error == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مرحباً بعودتك', style: AppTypography.h1),
            const SizedBox(height: AppSpacing.xs),
            const Text('أدخل بيانات حسابك للمتابعة', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'رقم الهاتف',
              hint: '0590000000',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'كلمة المرور',
              hint: '••••••••',
              controller: _password,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ErrorStateWidget(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'تسجيل الدخول',
              isLoading: _loading,
              onPressed: _login,
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isCaptain = false;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _plate = TextEditingController();
  final _city = TextEditingController();
  final _nationalId = TextEditingController();
  String _transport = 'motorcycle';
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final nationalId = _nationalId.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'يرجى إدخال الاسم الأول واسم العائلة');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_isCaptain && nationalId.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهوية الوطنية');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? error;
    try {
      if (_isCaptain) {
        error = await context.read<AuthCubit>().registerCaptain(
              firstName: firstName,
              lastName: lastName,
              phone: phone,
              password: password,
              transportType: _transport,
              plateNumber: _plate.text.trim().isEmpty ? null : _plate.text.trim(),
              city: _city.text.trim().isEmpty ? null : _city.text.trim(),
              nationalId: nationalId,
            );
      } else {
        error = await context.read<AuthCubit>().registerCustomer(
              firstName: firstName,
              lastName: lastName,
              phone: phone,
              password: password,
            );
      }
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('نوع الحساب', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('عميل')),
                ButtonSegment(value: true, label: Text('سائق توصيل')),
              ],
              selected: {_isCaptain},
              onSelectionChanged: (s) => setState(() => _isCaptain = s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'الاسم الأول',
                    controller: _firstName,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'اسم العائلة',
                    controller: _lastName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'رقم الهاتف',
              hint: '0590000000',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'كلمة المرور',
              hint: '••••••••',
              controller: _password,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
            ),
            if (_isCaptain) ...[
              const SizedBox(height: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('وسيلة النقل', style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: _transport,
                    items: const [
                      DropdownMenuItem(value: 'car', child: Text('سيارة')),
                      DropdownMenuItem(value: 'motorcycle', child: Text('دراجة نارية')),
                      DropdownMenuItem(value: 'bicycle', child: Text('دراجة هوائية')),
                      DropdownMenuItem(value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (v) => setState(() => _transport = v ?? 'motorcycle'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'رقم الهوية الوطنية',
                controller: _nationalId,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'رقم اللوحة (اختياري)',
                controller: _plate,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'المدينة (اختياري)',
                controller: _city,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ErrorStateWidget(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'إنشاء الحساب',
              isLoading: _loading,
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}