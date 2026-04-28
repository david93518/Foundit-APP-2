import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat.dart';
import '../../data/repositories/chat_repository.dart';
import 'core_providers.dart';

/// 聊天室清單
final chatsProvider = FutureProvider.autoDispose<List<Chat>>((ref) async {
  return ref.watch(chatRepositoryProvider).list();
});

/// 某聊天室的歷史訊息
final chatMessagesProvider =
    FutureProvider.autoDispose.family<List<Message>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).messages(chatId);
});

/// 我所有對話的累積未讀數 — 給底部 nav 訊息 tab 的 badge 使用
final chatUnreadTotalProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(chatRepositoryProvider).unreadTotal();
});

/// 送訊息 / 建立聊天室
class ChatActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChatActionsNotifier(this._repo) : super(const AsyncValue.data(null));
  final ChatRepository _repo;

  Future<Chat?> startChatWithItem(String itemId) async {
    state = const AsyncValue.loading();
    try {
      final chat = await _repo.createChat(itemId: itemId);
      state = const AsyncValue.data(null);
      return chat;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return null;
    }
  }

  Future<Message?> send({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      return await _repo.send(chatId: chatId, content: content, type: type);
    } catch (_) {
      return null;
    }
  }
}

final chatActionsProvider =
    StateNotifierProvider<ChatActionsNotifier, AsyncValue<void>>((ref) {
  return ChatActionsNotifier(ref.watch(chatRepositoryProvider));
});
