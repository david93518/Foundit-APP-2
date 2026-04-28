enum NotificationType { match, chat, itemUpdate, system }

class AppNotification {
  final String id;
  final String title;
  final String content;
  final NotificationType type;
  final String? itemId;
  final String? chatId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.content,
    this.type = NotificationType.system,
    this.itemId,
    this.chatId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime _ts(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return DateTime.fromMillisecondsSinceEpoch(p);
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    NotificationType _type(dynamic v) {
      final raw = (v?.toString() ?? '').toLowerCase();
      switch (raw) {
        case 'ai_match':
        case 'match':
          return NotificationType.match;
        case 'new_message':
        case 'chat':
          return NotificationType.chat;
        case 'nearby_item':
        case 'qr_scan':
        case 'reward':
        case 'item_update':
        case 'itemupdate':
          return NotificationType.itemUpdate;
        default:
          return NotificationType.system;
      }
    }

    final itemIdRaw = json['item_id']?.toString() ?? '';
    final chatIdRaw = json['chat_id']?.toString() ?? '';
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: _type(json['type']),
      itemId: itemIdRaw.isEmpty ? null : itemIdRaw,
      chatId: chatIdRaw.isEmpty ? null : chatIdRaw,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: _ts(json['created_at']),
    );
  }
}
