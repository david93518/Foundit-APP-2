import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/location_service.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/chat.dart';
import 'package:foundit/data/repositories/chat_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/chat/chat_list_screen.dart';
import 'package:foundit/presentation/screens/chat/chat_room_screen.dart';
import 'package:foundit/presentation/screens/map/map_screen.dart';
import 'package:foundit/presentation/screens/profile/collection_screen.dart';
import 'package:foundit/presentation/screens/profile/profile_screen.dart';
import 'package:foundit/presentation/screens/profile/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _longTitle = '深棕色皮革鑰匙包附有綠色恐龍吊飾與一張悠遊卡';
const _longPlace = '台北市大安區大安森林公園捷運站二號出口旁的便利商店服務櫃台';
const _sizes = [
  Size(320, 568),
  Size(390, 844),
  Size(844, 390),
  Size(768, 1024),
  Size(1440, 900),
];
const _scales = [1.0, 1.3, 2.0];

class _OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_tileBytes);
}

class _OfflineLocation extends LocationService {
  @override
  Future<LocationResult> currentPosition({Duration timeout = const Duration(seconds: 8)}) async =>
      const LocationResult(LocationResultCode.permissionDenied);
}

late Uint8List _tileBytes;

/// Real demonstration repository behavior with remote avatar URLs removed.
class _OfflineChats extends MockChatRepository {
  @override
  Future<List<Chat>> list() async => (await super.list())
      .map(
        (c) => Chat(
          id: c.id,
          itemId: c.itemId,
          itemTitle: _longTitle,
          otherUserName: c.id == 'c1' ? '在大安森林公園拾到物品的熱心朋友' : c.otherUserName,
          lastMessage: c.lastMessage,
          lastMessageAt: c.lastMessageAt,
          unreadCount: c.unreadCount,
        ),
      )
      .toList();
}

class _RejectedChats extends _OfflineChats {
  @override
  Future<Message?> send({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? clientMessageId,
  }) async => null;
}

Future<({GoRouter router, SharedPreferences prefs, _OfflineChats chats})>
_mount(
  WidgetTester tester,
  String page,
  Size size,
  double scale, {
  SharedPreferences? existingPrefs,
  _OfflineChats? existingChats,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (existingPrefs == null) {
    SharedPreferences.setMockInitialValues({
      'bookmark:guest:long-item': true,
      'foundit_my_item_ids': ['long-item'],
      AppConstants.prefRecentSearches: ['皮夾', '鑰匙'],
      'foundit_demo_items_v1': jsonEncode([
        {
          'id': 'long-item',
          'user_id': 'me',
          'user_name': '我',
          'type': 'found',
          'title': _longTitle,
          'category': '鑰匙',
          'color': '棕色',
          'images': [],
          'locationName': _longPlace,
          'latitude': 25.0338,
          'longitude': 121.537,
          'lostAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
          'created_at': DateTime(2026, 10, 3).millisecondsSinceEpoch,
          'updated_at': DateTime(2026, 10, 3).millisecondsSinceEpoch,
          'status': 'active',
        },
      ]),
    });
  }
  final prefs = existingPrefs ?? await SharedPreferences.getInstance();
  final chats = existingChats ?? _OfflineChats();
  final tiles = _OfflineTiles();
  final router = GoRouter(
    initialLocation: page,
    routes: [
      GoRoute(
        path: '/map',
        builder: (_, __) => Scaffold(body: MapScreen(tileProvider: tiles)),
      ),
      GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatRoomScreen(
          chatId: state.pathParameters['id']!,
          name: '在公園拾到物品的熱心朋友',
          itemTitle: _longTitle,
        ),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/saved',
        builder: (_, __) => const Scaffold(body: CollectionScreen(saved: true)),
      ),
      GoRoute(
        path: '/my-items',
        builder: (_, __) => const Scaffold(body: CollectionScreen()),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/item/:id',
        builder: (_, __) => const Scaffold(body: Text('物品詳情')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('探索失物')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        locationServiceProvider.overrideWithValue(_OfflineLocation()),
        chatRepositoryProvider.overrideWithValue(chats),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, prefs: prefs, chats: chats);
}

void _resetView(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final recording = ui.PictureRecorder();
    ui.Canvas(recording).drawColor(Colors.white, ui.BlendMode.src);
    final picture = recording.endRecording();
    final tile = await picture.toImage(1, 1);
    _tileBytes = (await tile.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    tile.dispose();
    picture.dispose();
    final loader = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await loader.load();
  });

  for (final page in [
    '/map',
    '/chats',
    '/chat/c1',
    '/profile',
    '/saved',
    '/settings',
  ]) {
    testWidgets('$page supports all viewports and 100–200% real Chinese text', (
      tester,
    ) async {
      _resetView(tester);
      for (final size in _sizes) {
        for (final scale in _scales) {
          await _mount(tester, page, size, scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '$page $size scale=$scale',
          );
          if (page == '/map') {
            await _tap(
              tester,
              find.byKey(const ValueKey('map-item-long-item')),
            );
            expect(find.text(_longTitle), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'selected map item $size scale=$scale',
            );
            await _tap(tester, find.byTooltip('關閉物品預覽'));
            await _tap(tester, find.text('協尋中'));
            expect(find.text('這裡還沒有標記'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'map filter empty state $size scale=$scale',
            );
          } else if (page == '/settings') {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -2400),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'settings bottom $size scale=$scale',
            );
          }
        }
      }
    });
  }

  testWidgets('unread filter updates after reading a demo conversation', (
    tester,
  ) async {
    _resetView(tester);
    final app = await _mount(tester, '/chats', const Size(320, 568), 2);
    await _tap(tester, find.text('未讀'));
    expect(find.text('Alice'), findsNothing);
    await _tap(tester, find.text('在大安森林公園拾到物品的熱心朋友'));
    expect(find.byType(ChatRoomScreen), findsOneWidget);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('訊息都讀完了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'composer remains usable with keyboard and retains drafts until sent',
    (tester) async {
      _resetView(tester);
      final app = await _mount(tester, '/chat/c1', const Size(320, 568), 2);
      final composer = find.byKey(const ValueKey('chat-composer'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.enterText(composer, '這是尚未送出的訊息草稿，請問方便明天下午領取嗎？');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(app.prefs.getString('chat_draft:guest:c1'), contains('尚未送出'));
      await _mount(
        tester,
        '/chat/c1',
        const Size(320, 568),
        2,
        existingPrefs: app.prefs,
        existingChats: app.chats,
      );
      expect(
        tester.widget<TextField>(composer).controller!.text,
        contains('尚未送出'),
      );
      await _tap(tester, find.byIcon(Icons.send_rounded));
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      expect(app.prefs.getString('chat_draft:guest:c1'), isEmpty);
      expect(find.textContaining('這是尚未送出的訊息草稿'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rejected send restores the draft instead of leaving a fake sent bubble',
    (tester) async {
      _resetView(tester);
      final app = await _mount(
        tester,
        '/chat/c1',
        const Size(320, 568),
        2,
        existingChats: _RejectedChats(),
      );
      final composer = find.byKey(const ValueKey('chat-composer'));
      await tester.enterText(composer, '請替我保留這段尚未送出的文字');
      await tester.pumpAndSettle();
      await _tap(tester, find.byIcon(Icons.send_rounded));
      expect(
        tester.widget<TextField>(composer).controller!.text,
        '請替我保留這段尚未送出的文字',
      );
      expect(app.prefs.getString('chat_draft:guest:c1'), '請替我保留這段尚未送出的文字');
      expect(find.textContaining('送出失敗'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile shortcuts, bookmark removal and settings actions work at 200%',
    (tester) async {
      _resetView(tester);
      final app = await _mount(tester, '/profile', const Size(320, 568), 2);
      await _tap(tester, find.text('收藏的物品'));
      expect(find.text(_longTitle), findsOneWidget);
      await _tap(tester, find.byTooltip('取消收藏 $_longTitle'));
      expect(find.text('還沒有收藏的物品'), findsOneWidget);
      expect(app.prefs.getBool('bookmark:guest:long-item'), isFalse);
      app.router.go('/settings');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('清除搜尋紀錄'));
      expect(app.prefs.getStringList(AppConstants.prefRecentSearches), isNull);
      await _tap(tester, find.text('資料與使用說明'));
      expect(find.text('我知道了'), findsOneWidget);
      await _tap(tester, find.text('我知道了'));
      expect(tester.takeException(), isNull);
    },
  );
}
