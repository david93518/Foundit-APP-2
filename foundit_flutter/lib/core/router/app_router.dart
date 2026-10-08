import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/chat.dart';
import '../../data/models/item.dart';
import '../../presentation/screens/ai/ai_match_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/otp_screen.dart';
import '../../presentation/screens/chat/chat_list_screen.dart';
import '../../presentation/screens/chat/chat_room_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/item/add_item_screen.dart';
import '../../presentation/screens/item/item_detail_screen.dart';
import '../../presentation/screens/item/location_picker_screen.dart';
import '../../presentation/screens/item/photo_viewer_screen.dart';
import '../../presentation/screens/main_shell.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/notification/notification_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/settings_screen.dart';
import '../../presentation/screens/qr/qr_scan_screen.dart';
import '../../presentation/screens/qr/qr_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/profile/collection_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/providers/auth_provider.dart';

/// 預設：iOS 風左滑 + 淡入（比 Material 預設更柔和）
CustomTransitionPage<T> _slidePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, anim, secAnim, c) {
      if (MediaQuery.of(context).disableAnimations) return c;
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: c,
        ),
      );
    },
  );
}

/// 垂直由下往上 — 適合相機、彈出性質頁面
CustomTransitionPage<T> _modalPage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    transitionsBuilder: (context, anim, secAnim, c) {
      if (MediaQuery.of(context).disableAnimations) return c;
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: c,
      );
    },
  );
}

/// 純淡入 — 用於照片檢視等 Hero 載體頁
CustomTransitionPage<T> _fadePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, anim, __, c) =>
        MediaQuery.of(context).disableAnimations
        ? c
        : FadeTransition(opacity: anim, child: c),
  );
}

/// 未登入也能進入的頁面；其餘頁面一律先登入。
const _publicPaths = {'/splash', '/login', '/otp', '/onboarding'};

/// 根據登入狀態決定導向：
/// - 尚未讀完本機登入快取 → 啟動畫面
/// - 未登入 → 登入頁（登入前看不到任何物品）
/// - 已登入卻停在登入／啟動頁 → 首頁
String? authRedirect(AuthState auth, String location) {
  if (!auth.ready) return location == '/splash' ? null : '/splash';
  final public = _publicPaths.contains(location);
  if (!auth.isLoggedIn) {
    return public && location != '/splash' ? null : '/login';
  }
  return public ? '/home' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<(bool, bool)>(
    authProvider.select((state) => (state.ready, state.isLoggedIn)),
    (_, __) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (_, state) =>
        authRedirect(ref.read(authProvider), state.matchedLocation),
    routes: _routes,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

final _routes = <RouteBase>[
  GoRoute(path: '/', redirect: (_, state) => '/home'),
  GoRoute(
    path: '/splash',
    pageBuilder: (_, state) => _fadePage(const SplashScreen(), state),
  ),
  GoRoute(
    path: '/onboarding',
    pageBuilder: (_, state) => _fadePage(const OnboardingScreen(), state),
  ),
  GoRoute(
    path: '/login',
    pageBuilder: (_, state) => _slidePage(const LoginScreen(), state),
  ),
  GoRoute(
    path: '/otp',
    pageBuilder: (_, state) =>
        _slidePage(OtpScreen(phone: state.extra as String? ?? ''), state),
  ),
  ShellRoute(
    builder: (ctx, state, child) =>
        MainShell(location: state.matchedLocation, child: child),
    routes: [
      GoRoute(
        path: '/saved',
        pageBuilder: (_, state) =>
            _fadePage(const CollectionScreen(saved: true), state),
      ),
      GoRoute(
        path: '/my-items',
        pageBuilder: (_, state) => _fadePage(const CollectionScreen(), state),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => _fadePage(const HomeScreen(), state),
      ),
      GoRoute(
        path: '/map',
        pageBuilder: (_, state) => _fadePage(const MapScreen(), state),
      ),
      GoRoute(
        path: '/chats',
        pageBuilder: (_, state) => _fadePage(const ChatListScreen(), state),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) => _fadePage(const ProfileScreen(), state),
      ),
    ],
  ),
  GoRoute(
    path: '/search',
    pageBuilder: (_, state) => _slidePage(const SearchScreen(), state),
  ),
  GoRoute(
    path: '/notifications',
    pageBuilder: (_, state) => _slidePage(const NotificationScreen(), state),
  ),
  GoRoute(
    path: '/qr',
    pageBuilder: (_, state) => _slidePage(const QrScreen(), state),
  ),
  GoRoute(
    path: '/qr/scan',
    pageBuilder: (_, state) => _modalPage(const QrScanScreen(), state),
  ),
  GoRoute(
    path: '/ai-match',
    pageBuilder: (_, state) => _modalPage(const AiMatchScreen(), state),
  ),
  GoRoute(
    path: '/profile/edit',
    pageBuilder: (_, state) => _modalPage(const EditProfileScreen(), state),
  ),
  GoRoute(
    path: '/settings',
    pageBuilder: (_, state) => _slidePage(const SettingsScreen(), state),
  ),
  GoRoute(
    path: '/item/:id',
    pageBuilder: (_, state) {
      final item = state.extra as Item?;
      final child = item == null
          ? ItemDetailRoute(id: state.pathParameters['id']!)
          : ItemDetailScreen(item: item);
      return _slidePage(child, state);
    },
  ),
  GoRoute(
    path: '/photo-viewer',
    pageBuilder: (_, state) {
      final data = state.extra as Map<String, dynamic>?;
      final images = (data?['images'] as List?)?.cast<String>() ?? const [];
      final initial = (data?['initialIndex'] as int?) ?? 0;
      final heroTag = data?['heroTag'] as String?;
      return _fadePage(
        PhotoViewerScreen(
          images: images,
          initialIndex: initial,
          heroTag: heroTag,
        ),
        state,
      );
    },
  ),
  GoRoute(
    path: '/add/:type',
    pageBuilder: (_, state) => _modalPage(
      AddItemScreen(type: state.pathParameters['type'] ?? 'lost'),
      state,
    ),
  ),
  GoRoute(
    path: '/location-picker',
    pageBuilder: (_, state) {
      final extra = state.extra is Map ? state.extra as Map : const {};
      return _modalPage(
        LocationPickerScreen(
          initialLatitude: extra['lat'] as double?,
          initialLongitude: extra['lng'] as double?,
          initialQuery: extra['query'] as String?,
        ),
        state,
      );
    },
  ),
  GoRoute(
    path: '/chat/:id',
    pageBuilder: (_, state) {
      final extra = state.extra;
      final id = state.pathParameters['id'] ?? '';
      Widget child;
      if (extra is Chat) {
        child = ChatRoomScreen(
          chatId: id,
          name: extra.otherUserName,
          avatar: extra.otherUserAvatar,
          itemTitle: extra.itemTitle,
        );
      } else if (extra is Map) {
        child = ChatRoomScreen(
          chatId: id,
          name: (extra['name'] as String?) ?? '',
          avatar: (extra['avatar'] as String?) ?? '',
          itemTitle: (extra['itemTitle'] as String?) ?? '',
        );
      } else {
        child = ChatRoomScreen(chatId: id);
      }
      return _slidePage(child, state);
    },
  ),
];
