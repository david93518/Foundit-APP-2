import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/app.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/push_notifications.dart';
import 'package:foundit/data/api/api_client.dart';
import 'package:foundit/presentation/providers/auth_provider.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/chat/chat_room_screen.dart';
import 'package:foundit/presentation/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePush extends PushNotifications {
  _FakePush(super.api);
  final opened = StreamController<String>.broadcast();
  final incoming = StreamController<ChatPush>.broadcast();
  final registered = <String>[];
  var unregistered = 0;

  @override
  Stream<String> get openedChats => opened.stream;
  @override
  Stream<ChatPush> get foreground => incoming.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> registerFor(String userId) async => registered.add(userId);
  @override
  Future<void> unregister() async => unregistered++;
}

void main() {
  testWidgets('push registers the signed-in device and opens the right chat', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({
      AppConstants.prefAuthToken: 'mock_token_xyz',
      AppConstants.prefUserId: 'u1',
      AppConstants.prefUserName: 'David',
      AppConstants.prefIsLoggedIn: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final push = _FakePush(ApiClient(prefs));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        pushNotificationsProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FounditApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(push.registered, contains('u1'));

    // 前景收到別的對話：提示條，點「查看」進聊天室。
    push.incoming.add(
      const ChatPush(chatId: 'c1', title: '小明 · 藍色後背包', body: '我在捷運站撿到了'),
    );
    await tester.pumpAndSettle();
    expect(find.text('小明 · 藍色後背包：我在捷運站撿到了'), findsOneWidget);
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatRoomScreen), findsOneWidget);
    expect(
      tester.widget<ChatRoomScreen>(find.byType(ChatRoomScreen)).chatId,
      'c1',
    );

    // 正在看這個對話：不再跳提示。
    push.incoming.add(const ChatPush(chatId: 'c1', title: '小明', body: '還在嗎'));
    await tester.pumpAndSettle();
    expect(find.text('小明：還在嗎'), findsNothing);

    // 點系統通知打開另一個對話。
    push.opened.add('c2');
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChatRoomScreen>(find.byType(ChatRoomScreen).last).chatId,
      'c2',
    );

    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(push.unregistered, 1);
    expect(tester.takeException(), isNull);
  });
}
