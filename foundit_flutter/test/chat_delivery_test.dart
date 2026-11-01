import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/chat_socket_service.dart';
import 'package:foundit/data/models/chat.dart';
import 'package:foundit/data/repositories/chat_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/safety_provider.dart';
import 'package:foundit/presentation/screens/chat/chat_room_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

class _ConnectedSocket extends ChatSocketService {
  _ConnectedSocket(super.prefs);
  @override
  Future<bool> connect() async => true;
  @override
  bool get isConnected => true;
}

class _Chats extends MockChatRepository {
  final delivery = Completer<Message?>();
  String? clientId;
  @override
  Future<List<Message>> messages(
    String chatId, {
    int page = 1,
    String? before,
  }) async => [];
  @override
  Future<List<Chat>> list() async => [];
  @override
  Future<int> unreadTotal() async => 0;
  @override
  Future<Message?> send({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? clientMessageId,
  }) {
    clientId = clientMessageId;
    return delivery.future;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_TW'));
  for (final succeeds in [true, false]) {
    testWidgets(
      'connected chat ${succeeds ? 'waits for persisted delivery' : 'restores rejected message draft'}',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AppConstants.prefUserId: 'owner',
        });
        final prefs = await SharedPreferences.getInstance();
        final chats = _Chats();
        final socket = _ConnectedSocket(prefs);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              useMockProvider.overrideWithValue(false),
              chatRepositoryProvider.overrideWithValue(chats),
              chatSocketServiceProvider.overrideWithValue(socket),
              blockedContactsProvider.overrideWith((_) async => []),
            ],
            child: const MaterialApp(
              home: ChatRoomScreen(chatId: 'room', name: '對方'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '確認送達');
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump();
        expect(chats.clientId, isNotEmpty);
        if (succeeds) {
          chats.delivery.complete(
            Message(
              id: 'persisted',
              chatId: 'room',
              senderId: 'owner',
              senderName: '我',
              content: '確認送達',
              createdAt: DateTime(2026),
              clientMessageId: chats.clientId!,
            ),
          );
        } else {
          chats.delivery.completeError(StateError('server unavailable'));
        }
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, succeeds ? '' : '確認送達');
        if (succeeds) expect(find.text('確認送達'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        socket.dispose();
      },
    );
  }
}
