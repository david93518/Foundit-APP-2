import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import 'core_providers.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    return ref.watch(notificationRepositoryProvider).list();
  },
);

/// 未讀通知數 — 直接打 `/notifications/unread-count`，不再依賴整包通知列表
final unreadCountAsyncProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

/// Sync 取值（給 UI 計算 badge），尚未載入時回 0
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(unreadCountAsyncProvider).asData?.value ?? 0;
});

class NotificationActions {
  NotificationActions(this._ref);
  final Ref _ref;

  Future<void> markRead(String id) async {
    final repo = _ref.read(notificationRepositoryProvider);
    await repo.markRead(id);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadCountAsyncProvider);
  }

  Future<void> markAllRead() async {
    final repo = _ref.read(notificationRepositoryProvider);
    await repo.markAllRead();
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadCountAsyncProvider);
  }
}

final notificationActionsProvider = Provider.autoDispose((ref) {
  return NotificationActions(ref);
});
