class ChatParticipant {
  final String id;
  final String name;
  final String phone;
  final String avatarUrl;

  const ChatParticipant({
    required this.id,
    this.name = '',
    this.phone = '',
    this.avatarUrl = '',
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) => ChatParticipant(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        avatarUrl:
            json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      );
}

class Chat {
  final String id;
  final String itemId;

  /// 由掃描防丟牌開啟的對話；此時 itemId 為空，itemTitle 是防丟牌名稱。
  final String qrItemId;
  final String itemTitle;
  final String itemImage;
  final List<ChatParticipant> participants;
  final String otherUserName;
  final String otherUserAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  const Chat({
    required this.id,
    this.itemId = '',
    this.qrItemId = '',
    this.itemTitle = '',
    this.itemImage = '',
    this.participants = const [],
    this.otherUserName = '',
    this.otherUserAvatar = '',
    this.lastMessage = '',
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    DateTime _ts(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return DateTime.fromMillisecondsSinceEpoch(p);
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Chat(
      id: json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      qrItemId: json['qr_item_id']?.toString() ?? '',
      itemTitle: json['item_title']?.toString() ?? '',
      itemImage: json['item_image']?.toString() ?? '',
      participants: (json['participants'] as List?)
              ?.map((e) => ChatParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      otherUserName: json['other_user_name']?.toString() ?? '',
      otherUserAvatar: json['other_user_avatar']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageAt: _ts(json['last_message_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

enum MessageType { text, image, location, system }

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final MessageType type;
  final DateTime? readAt;
  final DateTime createdAt;
  final String clientMessageId;

  const Message({
    required this.id,
    this.chatId = '',
    this.senderId = '',
    this.senderName = '',
    this.senderAvatar = '',
    this.content = '',
    this.type = MessageType.text,
    this.readAt,
    required this.createdAt,
    this.clientMessageId = '',
  });

  bool get isRead => readAt != null;

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    DateTime? readAt,
    DateTime? createdAt,
    String? clientMessageId,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    DateTime _ts(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return DateTime.fromMillisecondsSinceEpoch(p);
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? _tsOpt(dynamic v) => v == null ? null : _ts(v);

    return Message(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      senderAvatar: json['sender_avatar']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == (json['type']?.toString().toLowerCase() ?? 'text'),
        orElse: () => MessageType.text,
      ),
      readAt: _tsOpt(json['read_at']),
      createdAt: _ts(json['created_at']),
      clientMessageId: json['client_message_id']?.toString() ?? '',
    );
  }
}

extension MessageTypeWire on MessageType {
  String get wireValue => name.toUpperCase();
}
