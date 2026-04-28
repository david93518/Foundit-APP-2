import 'package:flutter/material.dart';
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
import '../../presentation/screens/splash/splash_screen.dart';

/// 預設：iOS 風左滑 + 淡入（比 Material 預設更柔和）
CustomTransitionPage<T> _slidePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, anim, secAnim, c) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
    transitionsBuilder: (_, anim, __, c) => FadeTransition(opacity: anim, child: c),
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (_, state) => _fadePage(const SplashScreen(), state),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, state) =>
          _fadePage(const OnboardingScreen(), state),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, state) => _slidePage(const LoginScreen(), state),
    ),
    GoRoute(
      path: '/otp',
      pageBuilder: (_, state) => _slidePage(
        OtpScreen(phone: state.extra as String? ?? ''),
        state,
      ),
    ),

    ShellRoute(
      builder: (ctx, state, child) =>
          MainShell(location: state.matchedLocation, child: child),
      routes: [
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
      pageBuilder: (_, state) =>
          _slidePage(const NotificationScreen(), state),
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
      pageBuilder: (_, state) =>
          _modalPage(const EditProfileScreen(), state),
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
            ? const Scaffold(body: Center(child: Text('找不到物品')))
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
  ],
);
