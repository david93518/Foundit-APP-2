import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'presentation/providers/auth_provider.dart';

class FounditApp extends ConsumerStatefulWidget {
  const FounditApp({super.key});

  @override
  ConsumerState<FounditApp> createState() => _FounditAppState();
}

class _FounditAppState extends ConsumerState<FounditApp> {
  StreamSubscription<void>? _unauthorizedSub;

  @override
  void initState() {
    super.initState();
    _unauthorizedSub = ApiClient.onUnauthorized.listen((_) async {
      // token 失效（401）：強制登出 + 跳到登入頁，避免一直 spinner
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {}
      if (!mounted) return;
      final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('登入逾時，請重新登入')),
        );
      }
      appRouter.go('/login');
    });
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'TW'),
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      locale: const Locale('zh', 'TW'),
    );
  }
}
