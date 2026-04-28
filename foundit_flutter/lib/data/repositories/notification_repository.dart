import '../api/api_client.dart';
import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> list();
  Future<bool> markRead(String id);
  Future<bool> markAllRead();

  /// 取得未讀數（首頁紅點 / 分頁 badge）
  Future<int> unreadCount();
}

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      title: 'AI 找到可能的配對！',
      content: '你遺失的「AirPods Pro 第二代」和 3 筆新上架物品相似度超過 85%',
      type: NotificationType.match,
      itemId: 'm1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: 'n2',
      title: '小林傳了新訊息',
      content: '請問方便今天下午取回嗎？',
      type: NotificationType.chat,
      chatId: 'c1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    AppNotification(
      id: 'n3',
      title: '你的物品已被收藏',
      content: '「銀色蘋果筆電」被 2 位使用者加入收藏',
      type: NotificationType.itemUpdate,
      itemId: 'm3',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: 'n4',
      title: '歡迎加入找得到 🎉',
      content: '完成你的第一筆刊登，即可獲得 50 積分！',
      type: NotificationType.system,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<List<AppNotification>> list() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _items;
  }

  @override
  Future<bool> markRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return false;
    final n = _items[i];
    _items[i] = AppNotification(
      id: n.id,
      title: n.title,
      content: n.content,
      type: n.type,
      itemId: n.itemId,
      chatId: n.chatId,
      isRead: true,
      createdAt: n.createdAt,
    );
    return true;
  }

  @override
  Future<bool> markAllRead() async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      _items[i] = AppNotification(
        id: n.id,
        title: n.title,
        content: n.content,
        type: n.type,
        itemId: n.itemId,
        chatId: n.chatId,
        isRead: true,
        createdAt: n.createdAt,
      );
    }
    return true;
  }

  @override
  Future<int> unreadCount() async {
    await Future.delayed(const Duration(milliseconds: 80));
    return _items.where((n) => !n.isRead).length;
  }
}

class RemoteNotificationRepository implements NotificationRepository {
  RemoteNotificationRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<AppNotification>> list() async {
    final res = await _api.get<Map<String, dynamic>>('/notifications');
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<bool> markRead(String id) async {
    final res = await _api.patch<Map<String, dynamic>>('/notifications/$id/read');
    return res.data?['success'] as bool? ?? false;
  }

  @override
  Future<bool> markAllRead() async {
    final res =
        await _api.patch<Map<String, dynamic>>('/notifications/read-all');
    return res.data?['success'] as bool? ?? false;
  }

  @override
  Future<int> unreadCount() async {
    try {
      final res = await _api
          .get<Map<String, dynamic>>('/notifications/unread-count');
      final data = res.data?['data'] as Map<String, dynamic>?;
      return (data?['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
