import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/chat_socket_service.dart';
import 'core/services/push_notifications.dart';
import 'core/services/tag_links.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/notifications_provider.dart';
import 'presentation/providers/theme_provider.dart';

class FounditApp extends ConsumerStatefulWidget {
  const FounditApp({super.key});

  @override
  ConsumerState<FounditApp> createState() => _FounditAppState();
}

class _FounditAppState extends ConsumerState<FounditApp>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _unauthorizedSub;
  final List<StreamSubscription<Object?>> _pushSubs = [];
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  GoRouter? _router;

  /// 還沒登入完成前點了通知：登入後再打開。
  String? _pendingChat;

  /// 還沒登入時用相機掃到的防丟牌：登入後再查詢。
  String? _pendingTag;
  final _tagLinks = TagLinks();
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

    final push = ref.read(pushNotificationsProvider);
    _pushSubs
      ..add(push.openedChats.listen(_openChat))
      ..add(push.foreground.listen(_onForegroundPush))
      ..add(
        ref
            .read(chatSocketServiceProvider)
            .inbox
            .listen((_) => _refreshInbox()),
      )
      ..add(_tagLinks.codes.listen(_openTag));
    _tagLinks.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectInbox());
    unawaited(
      push.initialize().then((_) {
        if (!mounted) return;
        final pending = push.pendingOpen;
        push.pendingOpen = null;
        if (pending != null) _openChat(pending);
        final userId = ref.read(authProvider).user?.id;
        if (userId != null) unawaited(push.registerFor(userId));
      }),
    );
  }

  void _openChat(String chatId) {
    if (!ref.read(authProvider).isLoggedIn || _router == null) {
      _pendingChat = chatId;
      return;
    }
    _pendingChat = null;
    final target = '/chat/$chatId';
    if (_currentPath() == target) return;
    _router!.push(target);
  }

  /// 冷啟動時登入狀態還在讀取、畫面還停在啟動頁：先記下來，進到首頁後再打開。
  void _openTag(String code) {
    _pendingTag = code;
    _flushPendingTag();
  }

  void _flushPendingTag([int attempt = 0]) {
    final code = _pendingTag;
    if (code == null || !mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.ready || !auth.isLoggedIn) return; // 登入後由 build 裡的監聽再呼叫
    final path = _currentPath();
    if (_router == null || path == null || path == '/splash') {
      if (attempt < 20) {
        Future<void>.delayed(
          const Duration(milliseconds: 250),
          () => _flushPendingTag(attempt + 1),
        );
      }
      return;
    }
    _pendingTag = null;
    _router!.push(
      Uri(path: '/qr/scan', queryParameters: {'code': code}).toString(),
    );
  }

  /// 目前最上層的頁面。push 進來的頁面不會反映在 configuration.uri，要看最後一個 match。
  String? _currentPath() {
    final router = _router;
    if (router == null) return null;
    final config = router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return null;
    final last = config.last;
    return (last is ImperativeRouteMatch ? last.matches : config).uri.path;
  }

  /// 登入後就保持一條即時連線：停在首頁時，底部「訊息」角標也會跟著新訊息更新。
  void _connectInbox() {
    if (!mounted || ref.read(useMockProvider)) return;
    if (!ref.read(authProvider).isLoggedIn) return;
    unawaited(ref.read(chatSocketServiceProvider).connect());
  }

  void _refreshInbox() {
    if (!mounted) return;
    ref
      ..invalidate(chatsProvider)
      ..invalidate(chatUnreadTotalProvider)
      ..invalidate(notificationsProvider)
      ..invalidate(unreadCountAsyncProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 背景期間系統可能切斷連線，也可能錯過推播：回到前景時重新連線並刷新未讀數。
    _connectInbox();
    if (ref.read(authProvider).isLoggedIn) _refreshInbox();
  }

  void _onForegroundPush(ChatPush push) {
    _refreshInbox();
    // 正在看這個對話：訊息已經即時出現在畫面上。
    if (_currentPath() == '/chat/${push.chatId}') return;
    final text = [push.title, push.body].where((s) => s.isNotEmpty).join('：');
    _messenger.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text.isEmpty ? '你有一則新訊息' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => _openChat(push.chatId),
          ),
        ),
      );
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
    for (final sub in _pushSubs) {
      sub.cancel();
    }
    _tagLinks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      authProvider.select((state) => state.ready && state.isLoggedIn),
      (_, signedIn) {
        if (signedIn) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _flushPendingTag(),
          );
        }
      },
    );
    ref.listen<String?>(authProvider.select((state) => state.user?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(chatSocketServiceProvider).disconnect();
        final push = ref.read(pushNotificationsProvider);
        if (next != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _connectInbox());
          unawaited(push.registerFor(next));
          final pending = _pendingChat;
          if (pending != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openChat(pending),
            );
          }
        } else if (previous != null) {
          unawaited(push.unregister());
        }
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
      routerConfig: _router = ref.watch(routerProvider(brightness)),
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
