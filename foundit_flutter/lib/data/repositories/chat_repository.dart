import '../api/api_client.dart';
import '../models/chat.dart';

abstract class ChatRepository {
  Future<List<Chat>> list();
  Future<Chat?> createChat({required String itemId});
  Future<List<Message>> messages(String chatId, {int page = 1});
  Future<Message?> send({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  });

  /// 將整個聊天室標記為已讀（REST，可作為 WebSocket 的 fallback）
  Future<bool> markRead(String chatId);

  /// 我的所有對話累積未讀總數（給 nav badge 用）
  Future<int> unreadTotal();
}

class MockChatRepository implements ChatRepository {
  final List<Chat> _chats = [
    Chat(
      id: 'c1',
      itemId: 'm1',
      itemTitle: 'AirPods Pro 第二代',
      itemImage: 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=400',
      otherUserName: '小林',
      otherUserAvatar: 'https://i.pravatar.cc/150?img=12',
      lastMessage: '請問方便今天下午取回嗎？',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 8)),
      unreadCount: 2,
    ),
    Chat(
      id: 'c2',
      itemId: 'm2',
      itemTitle: '黑色皮夾',
      itemImage: 'https://images.unsplash.com/photo-1627123424574-724758594e93?w=400',
      otherUserName: 'Alice',
      otherUserAvatar: 'https://i.pravatar.cc/150?img=47',
      lastMessage: '好的，我已經送到警衛室囉',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Chat(
      id: 'c3',
      itemId: 'm3',
      itemTitle: '銀色蘋果筆電',
      itemImage: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400',
      otherUserName: 'David',
      otherUserAvatar: 'https://i.pravatar.cc/150?img=33',
      lastMessage: '謝謝你幫忙！',
      lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final Map<String, List<Message>> _messages = {};

  @override
  Future<List<Chat>> list() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _chats;
  }

  @override
  Future<Chat?> createChat({required String itemId}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final existing = _chats.where((c) => c.itemId == itemId).toList();
    if (existing.isNotEmpty) return existing.first;
    final chat = Chat(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      itemId: itemId,
      itemTitle: '物品 $itemId',
      otherUserName: '對方',
      lastMessage: '',
      lastMessageAt: DateTime.now(),
    );
    _chats.insert(0, chat);
    return chat;
  }

  @override
  Future<List<Message>> messages(String chatId, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _messages[chatId] ??
        [
          Message(
            id: 'msg1',
            chatId: chatId,
            senderId: 'other',
            senderName: '對方',
            content: '你好，我在你的物品頁看到這個～',
            createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
            readAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          Message(
            id: 'msg2',
            chatId: chatId,
            senderId: 'me',
            senderName: '我',
            content: '嗨你好！請問現在方便嗎？',
            createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
            readAt: DateTime.now().subtract(const Duration(minutes: 8)),
          ),
        ];
  }

  @override
  Future<Message?> send(
      {required String chatId,
      required String content,
      MessageType type = MessageType.text}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final msg = Message(
      id: 'msg${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      senderName: '我',
      content: content,
      type: type,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(chatId, () => []).add(msg);
    return msg;
  }

  @override
  Future<bool> markRead(String chatId) async => true;

  @override
  Future<int> unreadTotal() async {
    return _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }
}

class RemoteChatRepository implements ChatRepository {
  RemoteChatRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Chat>> list() async {
    final res = await _api.get<Map<String, dynamic>>('/chats');
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) => Chat.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Chat?> createChat({required String itemId}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/chats',
      data: {'item_id': itemId},
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? null : Chat.fromJson(data);
  }

  @override
  Future<List<Message>> messages(String chatId, {int page = 1}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      query: {'page': page, 'page_size': 50},
    );
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Message?> send(
      {required String chatId,
      required String content,
      MessageType type = MessageType.text}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      data: {'content': content, 'type': type.name},
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? null : Message.fromJson(data);
  }

  @override
  Future<bool> markRead(String chatId) async {
    try {
      final res = await _api.patch<Map<String, dynamic>>('/chats/$chatId/read');
      return res.data?['success'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> unreadTotal() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/chats/unread-count');
      final data = res.data?['data'] as Map<String, dynamic>?;
      return (data?['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
