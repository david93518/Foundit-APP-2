import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/item/add_item_screen.dart';
import 'package:foundit/presentation/screens/item/item_detail_screen.dart';
import 'package:foundit/presentation/screens/profile/collection_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _titleKey = ValueKey('publish-title');
const _locationKey = ValueKey('publish-location');
const _storageKey = ValueKey('publish-storage');

Future<GoRouter> _mount(
  WidgetTester tester,
  SharedPreferences prefs, {
  String initial = '/add/found',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/add/:type',
        builder: (_, state) =>
            AddItemScreen(type: state.pathParameters['type'] ?? 'lost'),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (_, state) => ItemDetailRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-items',
        builder: (_, __) => const Scaffold(body: CollectionScreen()),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('探索物品')),
      ),
    ],
  );
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

Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Key key, String value) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'three steps validate required fields and preserve edits when going back',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final router = await _mount(tester, prefs);
      addTearDown(router.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _tapText(tester, '下一步：地點與時間');
      expect(find.text('請填寫物品名稱。'), findsOneWidget);
      expect(find.text('請選擇一個物品分類。'), findsOneWidget);
      expect(find.byKey(_titleKey), findsOneWidget);

      await _enter(tester, _titleKey, '銀色鑰匙圈');
      await _tapText(tester, '鑰匙');
      await _tapText(tester, '下一步：地點與時間');
      expect(find.text('2 / 3'), findsOneWidget);
      await _tapText(tester, '下一步：確認內容');
      expect(find.text('請填寫地點，讓附近的人更容易找到。'), findsOneWidget);

      await _enter(tester, _locationKey, '台北市中山區・雙連站');
      await _tapText(tester, '已交給店家或站務人員');
      await _tapText(tester, '下一步：確認內容');
      expect(find.text('請填寫保管單位，方便失主詢問。'), findsOneWidget);
      await _enter(tester, _storageKey, '雙連站服務台');

      await _tapText(tester, '上一步');
      expect(
        tester.widget<TextFormField>(find.byKey(_titleKey)).controller!.text,
        '銀色鑰匙圈',
      );
      await _tapText(tester, '下一步：地點與時間');
      expect(
        tester.widget<TextFormField>(find.byKey(_locationKey)).controller!.text,
        '台北市中山區・雙連站',
      );
      expect(
        tester.widget<TextFormField>(find.byKey(_storageKey)).controller!.text,
        '雙連站服務台',
      );

      // The picker itself prevents choosing a future date.
      final date = DateTime.now();
      await _tapText(tester, '${date.year} 年 ${date.month} 月 ${date.day} 日');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateUtils.dateOnly(date));
      await _tapText(tester, '取消');
      await _tapText(tester, '下一步：確認內容');
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('銀色鑰匙圈'), findsOneWidget);
      expect(find.text('已交給店家或站務人員・雙連站服務台'), findsOneWidget);
      expect(prefs.getStringList('foundit_my_item_ids'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mock publish persists once and resolving returns to my listings',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final router = await _mount(tester, prefs);
      addTearDown(router.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _enter(tester, _titleKey, '綠色鑰匙圈');
      await _tapText(tester, '鑰匙');
      await _tapText(tester, '下一步：地點與時間');
      await _enter(tester, _locationKey, '台北市大安區・大安森林公園');
      await _tapText(tester, '下一步：確認內容');
      expect(find.textContaining('不會發布給其他使用者'), findsWidgets);
      await tester.ensureVisible(find.text('我已閱讀並同意刊登規範'));
      await tester.tap(find.text('我已閱讀並同意刊登規範'));
      await tester.pumpAndSettle();

      // A second tap during the pending request must not create another listing.
      final publish = find.text('建立體驗刊登');
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      final ids = prefs.getStringList('foundit_my_item_ids')!;
      expect(ids, hasLength(1));
      expect(
        router.routeInformationProvider.value.uri.path,
        '/item/${ids.single}',
      );
      expect(find.text('標記為已交還'), findsOneWidget);
      final saved =
          jsonDecode(prefs.getString('foundit_demo_items_v1')!) as List;
      final created =
          saved.singleWhere((row) => row['id'] == ids.single) as Map;
      expect(created['title'], '綠色鑰匙圈');
      expect(created['user_id'], 'me');
      expect(created['locationName'], '台北市大安區・大安森林公園');

      await _tapText(tester, '標記為已交還');
      await _tapText(tester, '確認完成');
      expect(router.routeInformationProvider.value.uri.path, '/my-items');
      expect(find.text('我的刊登'), findsOneWidget);
      expect(find.text('綠色鑰匙圈'), findsOneWidget);
      expect(find.text('已交還'), findsOneWidget);

      // Recreate the entire provider scope to prove this is device storage,
      // rather than data kept alive by the publishing screen.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final restoredRouter = await _mount(tester, prefs, initial: '/my-items');
      addTearDown(restoredRouter.dispose);
      expect(find.text('綠色鑰匙圈'), findsOneWidget);
      expect(find.text('已交還'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
