import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/item/add_item_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hintTitle = '物品上有 FOUND !T 防丟牌？';
const _hintKey = ValueKey('found-scan-hint');

final _foundItem = Item(
  id: 'found-umbrella',
  type: ItemType.found,
  userId: 'me',
  title: '藍色雨傘',
  category: '其他',
  locationName: '台北車站',
  lostAt: DateTime(2026, 10, 1),
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

Future<GoRouter> _mount(WidgetTester tester, String initial) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/add/:type',
        builder: (_, state) =>
            AddItemScreen(type: state.pathParameters['type'] ?? 'lost'),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, __) => AddItemScreen(editing: _foundItem),
      ),
      GoRoute(
        path: '/qr/scan',
        builder: (_, __) => const Scaffold(body: Text('防丟牌掃描畫面')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets('found mode offers scanning a tag instead of publishing', (
    tester,
  ) async {
    final router = await _mount(tester, '/add/found');
    expect(find.text(_hintTitle), findsOneWidget);
    expect(find.text('直接掃描，就能傳訊息給物主，不必刊登。'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_hintKey),
        matching: find.byIcon(Icons.qr_code_scanner_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(_hintKey)).height,
      greaterThanOrEqualTo(48),
    );
    final semantics = tester.getSemantics(find.byKey(_hintKey));
    expect(semantics.label, startsWith('掃描防丟牌'));
    expect(semantics, isSemantics(isButton: true, hasTapAction: true));

    await tester.tap(find.byKey(_hintKey));
    await tester.pumpAndSettle();
    expect(find.text('防丟牌掃描畫面'), findsOneWidget);
    // 以 push 開啟，返回後回到原本的表單。
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(_hintTitle), findsOneWidget);
  });

  testWidgets('lost mode hides the hint until the type switches to found', (
    tester,
  ) async {
    await _mount(tester, '/add/lost');
    expect(find.text(_hintTitle), findsNothing);
    expect(find.byKey(_hintKey), findsNothing);

    final found = find.text('我撿到了物品');
    await tester.ensureVisible(found);
    await tester.pumpAndSettle();
    await tester.tap(found);
    await tester.pumpAndSettle();
    expect(find.text(_hintTitle), findsOneWidget);

    final lost = find.text('我遺失了物品');
    await tester.ensureVisible(lost);
    await tester.pumpAndSettle();
    await tester.tap(lost);
    await tester.pumpAndSettle();
    expect(find.text(_hintTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a found listing does not show the hint', (tester) async {
    await _mount(tester, '/edit');
    // 確認是發布者的編輯表單，而不是無權限的提示頁。
    expect(find.text('編輯刊登'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text(_hintTitle), findsNothing);
    expect(find.byKey(_hintKey), findsNothing);
  });
}
