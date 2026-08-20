import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember) {
      final savedPhone = prefs.getString('saved_phone');
      final savedPass = prefs.getString('saved_password');
      if (savedPhone != null && savedPhone.isNotEmpty) {
        setState(() {
          _rememberMe = true;
          _phone.text = savedPhone;
          if (savedPass != null) _password.text = savedPass;
        });
      }
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_phone', _phone.text.trim());
      await prefs.setString('saved_password', _password.text);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('saved_phone');
      await prefs.remove('saved_password');
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    final phoneStr = _phone.text.trim();
    final passStr = _password.text;
    if (phoneStr.isEmpty || passStr.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AApi.instance.login(phoneStr, passStr);
      await _saveCredentials();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ae(e);
      });
    }
  }

  void _copyError() {
    if (_error == null) return;
    Clipboard.setData(ClipboardData(text: _error!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ نص الخطأ بنجاح'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ATheme.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.admin_panel_settings, size: 40, color: ATheme.primary),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'لوحة تحكم توصيل',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'تسجيل الدخول لحساب الإدارة',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف أو البريد الإلكتروني',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: ATheme.primary,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: const Text(
                              'تذكر بيانات الدخول',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: ATheme.danger.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ATheme.danger.withValues(alpha: .3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ATheme.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  _error!,
                                  style: const TextStyle(color: ATheme.danger, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: ATheme.danger, size: 18),
                                tooltip: 'نسخ نص الخطأ',
                                onPressed: _copyError,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}