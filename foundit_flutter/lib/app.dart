import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/chat_socket_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_provider.dart';

class FounditApp extends ConsumerStatefulWidget {
  const FounditApp({super.key});

  @override
  ConsumerState<FounditApp> createState() => _FounditAppState();
}

class _FounditAppState extends ConsumerState<FounditApp>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _unauthorizedSub;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Brightness _platform =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next != _platform) setState(() => _platform = next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final brightness = ref.watch(themeModeProvider).resolve(_platform);
    final isDark = brightness == Brightness.dark;
    // 在任何子 widget 建立之前先切換全域色票。路由（連同整棵頁面樹）會依
    // 亮暗重新建立，所以不會有用舊顏色排版過的文字留在畫面上。
    if (AppColors.brightness != brightness) {
      AppColors.brightness = brightness;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
        ),
      );
    }
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(routerProvider(brightness)),
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
