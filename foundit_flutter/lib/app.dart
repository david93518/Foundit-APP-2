import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'core/services/chat_socket_service.dart';
import 'presentation/providers/auth_provider.dart';

class FounditApp extends ConsumerStatefulWidget {
  const FounditApp({super.key});

  @override
  ConsumerState<FounditApp> createState() => _FounditAppState();
}

class _FounditAppState extends ConsumerState<FounditApp> {
  StreamSubscription<void>? _unauthorizedSub;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _unauthorizedSub = ApiClient.onUnauthorized.listen((_) async {
      // token 失效（401）：清掉登入狀態，路由守衛會自動帶回登入頁
      final wasLoggedIn = ref.read(authProvider).isLoggedIn;
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {}
      if (!mounted || !wasLoggedIn) return;
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('登入已過期，請重新登入')),
      );
    });
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(authProvider.select((state) => state.user?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(chatSocketServiceProvider).disconnect();
      }
    });
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
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
