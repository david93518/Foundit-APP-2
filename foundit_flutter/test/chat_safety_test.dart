import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/core/services/chat_socket_service.dart';
import 'package:foundit/data/api/api_client.dart';
import 'package:foundit/data/models/chat.dart';
import 'package:foundit/data/repositories/chat_repository.dart';
import 'package:foundit/data/repositories/safety_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/safety_provider.dart';
import 'package:foundit/presentation/screens/chat/chat_room_screen.dart';
import 'package:foundit/presentation/screens/profile/safety_screen.dart';
import 'package:foundit/presentation/widgets/report_user_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakeSafety extends SafetyRepository {
  FakeSafety(super.api);
  final blocked = <BlockedContact>[];
  final reports = <String>[];
  bool fail = false;
  @override
  Future<List<BlockedContact>> blockedContacts() async => blocked.toList();
  @override
  Future<void> block(String userId) async {
    if (fail) throw StateError('offline');
    blocked.add(BlockedContact(id: userId, name: '小林'));
  }

  @override
  Future<void> unblock(String userId) async {
    if (fail) throw StateError('offline');
    blocked.removeWhere((p) => p.id == userId);
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    if (fail) throw StateError('offline');
    reports.add('$userId:$reason');
  }
}

class TestSocket extends ChatSocketService {
  TestSocket(super.prefs);
  final events = StreamController<ChatSocketStatus>.broadcast();
  final incoming = StreamController<Message>.broadcast();
  final receipts = StreamController<ChatReadEvent>.broadcast();
  @override
  Stream<ChatSocketStatus> get status => events.stream;
  @override
  Stream<Message> get messages => incoming.stream;
  @override
  Stream<ChatReadEvent> get reads => receipts.stream;
  @override
  Future<bool> connect() async => true;
  @override
  ChatSocketStatus get currentStatus => ChatSocketStatus.connected;
  @override
  void dispose() {
    events.close();
    incoming.close();
    receipts.close();
    super.dispose();
  }
}

Message msg(int i) => Message(
  id: 'm${i.toString().padLeft(3, '0')}',
  chatId: 'room',
  senderId: 'peer',
  senderName: '小林',
  content: '訊息 $i',
  createdAt: DateTime(2026, 10, 8, 10, i),
);

class History extends MockChatRepository {
  final rows = List.generate(75, msg);
  String? cursor;
  bool fail = false;
  int fetches = 0;
  final reads = <String?>[];
  @override
  Future<Chat?> detail(String id) async => Chat(
    id: id,
    itemId: 'item',
    itemTitle: '水壺',
    lastMessageAt: DateTime(2026),
    participants: const [
      ChatParticipant(id: 'owner'),
      ChatParticipant(id: 'peer'),
    ],
    otherUserName: '小林',
  );
  @override
  Future<List<Message>> messages(
    String chatId, {
    int page = 1,
    String? before,
  }) async {
    fetches++;
    if (fail) throw StateError('offline');
    cursor = before;
    final end = before == null
        ? rows.length
        : rows.indexWhere((m) => m.id == before);
    return rows.sublist((end - 50).clamp(0, end), end);
  }

  @override
  Future<bool> markRead(String chatId, {String? upToMessageId}) async {
    reads.add(upToMessageId);
    return true;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_TW');
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });
  final preview = GlobalKey();
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_SAFETY8')) return;
    await tester.runAsync(() async {
      final boundary =
          preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/safety8-previews').createSync(recursive: true);
      File('build/safety8-previews/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  late SharedPreferences prefs;
  late FakeSafety safety;
  late History history;
  late TestSocket socket;
  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.prefUserId: 'owner'});
    prefs = await SharedPreferences.getInstance();
    safety = FakeSafety(ApiClient(prefs));
    history = History();
    socket = TestSocket(prefs);
  });
  tearDown(() => socket.dispose());
  Future<void> mount(
    WidgetTester tester, {
    Widget? screen,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(false),
          chatRepositoryProvider.overrideWithValue(history),
          chatSocketServiceProvider.overrideWithValue(socket),
          safetyRepositoryProvider.overrideWithValue(safety),
        ],
        child: RepaintBoundary(
          key: preview,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: screen ?? const ChatRoomScreen(chatId: 'room', name: '小林'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('對話選單'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'older cursor retrieves earlier history; reconnect and resume recover missed messages',
    (tester) async {
      await mount(tester);
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('load-older')));
      await tester.pumpAndSettle();
      expect(history.cursor, 'm025');
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('訊息 0'), findsOneWidget);
      expect(find.text('已到對話開頭'), findsOneWidget);
      // More than a page was missed: reset the window so older paging stays contiguous.
      history.rows.addAll(List.generate(60, (i) => msg(i + 75)));
      socket.events.add(ChatSocketStatus.connected);
      await tester.pumpAndSettle();
      expect(find.text('訊息 134'), findsOneWidget);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('load-older')));
      await tester.pumpAndSettle();
      expect(history.cursor, 'm085');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      history.rows.add(msg(135));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('訊息 135'), findsOneWidget);
      history.fail = true;
      socket.events.add(ChatSocketStatus.connected);
      await tester.pumpAndSettle();
      expect(find.text('訊息尚未同步，請重試'), findsOneWidget);
      expect(find.text('訊息 135'), findsOneWidget);
      history.fail = false;
      await tester.tap(find.text('訊息尚未同步，請重試'));
      await tester.pumpAndSettle();
      expect(find.text('訊息尚未同步，請重試'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'messages arriving while reading history do not jump or falsely mark read',
    (tester) async {
      await mount(tester);
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final count = history.reads.length;
      socket.incoming.add(msg(75));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(history.reads.length, count);
      expect(find.text('有新訊息，前往最新'), findsOneWidget);
      await tester.tap(find.text('有新訊息，前往最新'));
      await tester.pumpAndSettle();
      expect(history.reads.last, 'm075');
      expect(find.text('訊息 75'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('chat block confirmation cancel, failure, success and unblock', (
    tester,
  ) async {
    await mount(tester);
    await menu(tester, '封鎖聯絡');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(safety.blocked, isEmpty);
    await menu(tester, '封鎖聯絡');
    safety.fail = true;
    await tester.tap(find.text('封鎖聯絡'));
    await tester.pumpAndSettle();
    expect(safety.blocked, isEmpty);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
    safety.fail = false;
    await menu(tester, '封鎖聯絡');
    await tester.tap(find.text('封鎖聯絡'));
    await tester.pumpAndSettle();
    expect(safety.blocked.single.id, 'peer');
    expect(find.byKey(const ValueKey('chat-composer')), findsNothing);
    ScaffoldMessenger.of(tester.element(find.byType(ChatRoomScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('已封鎖聯絡 · 解除封鎖'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解除封鎖'));
    await tester.pumpAndSettle();
    expect(safety.blocked, isEmpty);
    expect(find.byKey(const ValueKey('chat-composer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('read receipts stop at the reported message, not all messages', (
    tester,
  ) async {
    history.rows.clear();
    history.rows.addAll([
      for (var i = 0; i < 2; i++)
        Message(
          id: 'own$i',
          chatId: 'room',
          senderId: 'owner',
          senderName: '我',
          content: '我的訊息 $i',
          createdAt: DateTime(2026, 10, 8, 10, i),
        ),
    ]);
    await mount(tester);
    socket.receipts.add(const ChatReadEvent('room', 'peer', 'not-loaded'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    socket.receipts.add(const ChatReadEvent('room', 'peer', 'own0'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('safety actions remain usable at $size with 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      history.rows.clear();
      await mount(tester, scale: 2);
      await menu(tester, '交還前核對');
      expect(find.text('交還前，先確認這些'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await menu(tester, '檢舉對方');
      await capture(tester, 'report-${size.width.toInt()}');
      await tester.ensureVisible(find.text('送出檢舉'));
      await tester.pumpAndSettle();
      safety.fail = true;
      await tester.tap(find.text('送出檢舉'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportUserDialog), findsOneWidget);
      expect(safety.reports, isEmpty);
      safety.fail = false;
      await tester.tap(find.text('送出檢舉'));
      await tester.pumpAndSettle();
      expect(safety.reports.single, 'peer:騷擾或不當言語');
      expect(find.byType(ReportUserDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      safety.blocked.add(const BlockedContact(id: 'peer', name: '名稱非常長的測試使用者'));
      await mount(tester, scale: 2, screen: const SafetyScreen());
      await capture(tester, 'safety-${size.width.toInt()}');
      await tester.scrollUntilVisible(
        find.text('解除封鎖'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, '解除封鎖'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('解除封鎖'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '解除封鎖'));
      await tester.pumpAndSettle();
      expect(safety.blocked, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
