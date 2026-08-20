import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/socket_service.dart';
import 'core/network/push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_screens.dart';

import 'core/widgets/web_responsive_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final authCubit = AuthCubit();
  runApp(TwsilApp(authCubit: authCubit));
  authCubit.bootstrap();
  PushService.init();
}

class TwsilApp extends StatefulWidget {
  final AuthCubit authCubit;
  const TwsilApp({super.key, required this.authCubit});

  @override
  State<TwsilApp> createState() => _TwsilAppState();
}

class _TwsilAppState extends State<TwsilApp> {
  @override
  void dispose() {
    SocketService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => widget.authCubit,
      child: MaterialApp(
        title: 'توصيل | منصة التوصيل المباشر والتفاوض',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => WebResponsiveWrapper(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}