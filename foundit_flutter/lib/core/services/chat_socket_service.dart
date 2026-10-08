import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../data/models/chat.dart';
import '../constants/app_constants.dart';
import '../../presentation/providers/core_providers.dart';

/// WebSocket 聊天連線狀態
enum ChatSocketStatus { idle, connecting, connected, disconnected, error }

/// 對方標記已讀的事件
class ChatReadEvent {
  final String chatId;
  final String userId;
  const ChatReadEvent(this.chatId, this.userId);
}

/// 與後端 `chats.gateway.ts`（namespace = `/chat`）對接的單例 WebSocket 服務。
///
/// 使用方式：
/// ```
/// final svc = ref.read(chatSocketServiceProvider);
/// await svc.connect();
/// svc.joinChat(chatId);
/// svc.sendMessage(chatId: chatId, content: 'hi');
/// svc.messages.where((m) => m.chatId == chatId).listen(...);
/// ```
class ChatSocketService {
  ChatSocketService(this._prefs);

  final SharedPreferences _prefs;
  io.Socket? _socket;
  String? _token;

  final _messages = StreamController<Message>.broadcast();
  final _reads = StreamController<ChatReadEvent>.broadcast();
  final _status = StreamController<ChatSocketStatus>.broadcast();

  ChatSocketStatus _currentStatus = ChatSocketStatus.idle;

  Stream<Message> get messages => _messages.stream;
  Stream<ChatReadEvent> get reads => _reads.stream;
  Stream<ChatSocketStatus> get status => _status.stream;
  ChatSocketStatus get currentStatus => _currentStatus;

  bool get isConnected => _socket?.connected ?? false;

  /// 建立或重用 WebSocket 連線。
  /// 沒有 token 會直接 fail（回傳 false），呼叫端自行決定是否提示登入。
  Future<bool> connect() async {
    final token = _prefs.getString(AppConstants.prefAuthToken);
    if (token == null || token.isEmpty) {
      _emitStatus(ChatSocketStatus.error);
      return false;
    }
    if (_socket != null && _socket!.connected && _token == token) return true;
    disconnect();
    _token = token;

    _emitStatus(ChatSocketStatus.connecting);

    final url = '${AppConstants.socketHost}${AppConstants.socketChatNamespace}';
    _socket?.dispose();
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1000)
          .setAuth({'token': 'Bearer $token'})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (kDebugMode) debugPrint('[ChatSocket] connected');
        _emitStatus(ChatSocketStatus.connected);
      })
      ..onDisconnect((_) {
        if (kDebugMode) debugPrint('[ChatSocket] disconnected');
        _emitStatus(ChatSocketStatus.disconnected);
      })
      ..onConnectError((e) {
        if (kDebugMode) debugPrint('[ChatSocket] connect error: $e');
        _emitStatus(ChatSocketStatus.error);
      })
      ..onError((e) {
        if (kDebugMode) debugPrint('[ChatSocket] error: $e');
      })
      ..on('message', _handleMessage)
      ..on('read', _handleRead);

    _socket!.connect();
    return true;
  }

  void joinChat(String chatId) {
    _socket?.emit('join', {'chatId': chatId});
  }

  /// 經 socket 送訊息；server 收到會 broadcast 回 'message' 事件，本端會在 `messages` stream 收到
  void sendMessage({
    required String chatId,
    required String content,
    String type = 'TEXT',
    String? clientMessageId,
  }) {
    _socket?.emit('message', {
      'chatId': chatId,
      'content': content,
      'type': type.toUpperCase(),
      if (clientMessageId != null) 'client_message_id': clientMessageId,
    });
  }

  void markRead(String chatId, {String? upToMessageId}) {
    if (upToMessageId == null || upToMessageId.isEmpty) return;
    _socket?.emit('read', {'chatId': chatId, 'upToMessageId': upToMessageId});
  }

  void disconnect() {
    _token = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _emitStatus(ChatSocketStatus.idle);
  }

  void dispose() {
    disconnect();
    _messages.close();
    _reads.close();
    _status.close();
  }

  void _handleMessage(dynamic data) {
    try {
      if (data is Map) {
        final msg = Message.fromJson(Map<String, dynamic>.from(data));
        _messages.add(msg);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatSocket] parse message failed: $e');
    }
  }

  void _handleRead(dynamic data) {
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        _reads.add(
          ChatReadEvent(
            (m['chatId'] ?? m['chat_id'] ?? '').toString(),
            (m['userId'] ?? m['user_id'] ?? '').toString(),
          ),
        );
      }
    } catch (_) {}
  }

  void _emitStatus(ChatSocketStatus s) {
    _currentStatus = s;
    _status.add(s);
  }
}

/// 全域單例 — App 啟動後只有一個連線
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final svc = ChatSocketService(prefs);
  ref.onDispose(svc.dispose);
  return svc;
});
