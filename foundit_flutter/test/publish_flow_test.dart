import 'dart:convert';

import 'support/location_picker_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/repositories/item_repository.dart';
import 'package:foundit/data/models/item.dart';
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
  MockItemRepository? repository,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      locationPickerStub(),
      GoRoute(
        path: '/item/:id/edit',
        builder: (_, state) => EditItemRoute(id: state.pathParameters['id']!),
      ),
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
        if (repository != null)
          itemRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
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
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Key key, String value) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
  if (key == _locationKey) {
    await _tapText(tester, '確認地圖位置（必填）');
    await _tapText(tester, '使用此位置');
  }
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
    'editing preserves identity and photos, failed save can retry without a duplicate',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FailOnceRepository(prefs);
      final item = await _seedOwned(tester, repo, prefs);
      final router = await _mount(
        tester,
        prefs,
        repository: repo,
        initial: '/item/${item.id}',
      );
      addTearDown(router.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _tapText(tester, '編輯刊登');
      expect(
        tester.widget<TextFormField>(find.byKey(_titleKey)).controller!.text,
        '原本刊登',
      );
      expect(find.byTooltip('移除照片'), findsNWidgets(2));
      await tester.ensureVisible(find.byTooltip('移除照片').first);
      await tester.tap(find.byTooltip('移除照片').first);
      await _enter(tester, _titleKey, '修改後的水壺');
      await _tapText(tester, '下一步：地點與時間');
      await _tapText(tester, '下一步：確認內容');
      await _tapText(tester, '儲存修改');
      expect(find.text('修改尚未儲存。輸入已保留，請檢查連線後重試。'), findsOneWidget);
      expect(find.text('修改後的水壺'), findsOneWidget);
      await _tapText(tester, '儲存修改');
      expect(find.text('儲存修改'), findsNothing);
      expect(find.text('修改後的水壺'), findsOneWidget);
      final restored = await tester.runAsync(
        () => MockItemRepository(prefs: prefs).detail(item.id),
      );
      expect(restored!.id, item.id);
      expect(restored.images, ['assets/images/tote.jpg']);
      expect(restored.userId, item.userId);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        item.createdAt.millisecondsSinceEpoch,
      );
      expect(restored.reward, 500);
      expect(restored.hasReward, isTrue);
      expect(prefs.getStringList('foundit_my_item_ids'), [item.id]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'owner edit cancel and confirmed deletion at $size 200 percent text',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final repo = MockItemRepository(prefs: prefs);
        final item = await _seedOwned(tester, repo, prefs);
        final router = await _mount(
          tester,
          prefs,
          repository: repo,
          initial: '/item/${item.id}',
          size: size,
          textScale: 2,
        );
        addTearDown(router.dispose);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _tapText(tester, '編輯刊登');
        await _enter(tester, _titleKey, '放棄的修改');
        final back = find.byTooltip('返回原刊登');
        if (back.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            back,
            -250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 80,
          );
        }
        await tester.ensureVisible(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();
        await _tapText(tester, '放棄修改');
        expect(find.text('放棄的修改'), findsNothing);
        await _tapText(tester, '刪除刊登');
        await _tapText(tester, '保留刊登');
        expect(
          (await tester.runAsync(() => repo.detail(item.id)))?.title,
          '原本刊登',
        );
        await _tapText(tester, '刪除刊登');
        await _tapText(tester, '確認刪除');
        expect(find.text('我的刊登'), findsOneWidget);
        expect(find.text('原本刊登'), findsNothing);
        expect(
          await tester.runAsync(
            () => MockItemRepository(prefs: prefs).detail(item.id),
          ),
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed deletion stays on detail and does not claim success', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = _FailOnceRepository(prefs);
    final item = await _seedOwned(tester, repo, prefs);
    final router = await _mount(
      tester,
      prefs,
      repository: repo,
      initial: '/item/${item.id}',
    );
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _tapText(tester, '刪除刊登');
    await _tapText(tester, '確認刪除');
    expect(find.text('尚未刪除，請檢查連線後重試。'), findsOneWidget);
    expect(find.text('刊登已刪除。'), findsNothing);
    expect(await tester.runAsync(() => repo.detail(item.id)), isNotNull);
    expect(find.text('刪除刊登'), findsOneWidget);
  });

  testWidgets('another users listing never offers edit or delete', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = MockItemRepository(prefs: prefs);
    final others = await tester.runAsync(() => repo.list(const ItemFilter()));
    final router = await _mount(
      tester,
      prefs,
      repository: repo,
      initial: '/item/${others!.first.id}',
    );
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(find.text('編輯刊登'), findsNothing);
    expect(find.text('刪除刊登'), findsNothing);
    router.go('/item/${others.first.id}/edit');
    await tester.pumpAndSettle();
    expect(find.text('只有發布者可以編輯尚未結束的刊登。'), findsOneWidget);
    expect(find.byKey(_titleKey), findsNothing);
  });

  testWidgets('owner can add a missing location to an existing listing', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = MockItemRepository(prefs: prefs);
    final now = DateTime.now();
    final item = await tester.runAsync(
      () => repo.create(
        Item(
          id: '',
          type: ItemType.found,
          title: '舊刊登',
          category: '其他',
          locationName: '成大',
          lostAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    final router = await _mount(tester, prefs, initial: '/item/${item!.id}');
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _tapText(tester, '補上地圖位置');
    await _tapText(tester, '使用此位置');
    expect(find.text('補上地圖位置'), findsNothing);
    expect(find.text('調整地圖位置'), findsOneWidget);
    final restored = await tester.runAsync(
      () => MockItemRepository(prefs: prefs).detail(item.id),
    );
    expect(restored?.hasMapPosition, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location text alone cannot advance to publish confirmation', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final router = await _mount(tester, prefs);
    addTearDown(router.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _enter(tester, _titleKey, '需要定位的物品');
    await _tapText(tester, '鑰匙');
    await _tapText(tester, '下一步：地點與時間');
    await tester.ensureVisible(find.byKey(_locationKey));
    await tester.enterText(find.byKey(_locationKey), '成大');
    await _tapText(tester, '下一步：確認內容');
    expect(find.text('使用此位置'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await _tapText(tester, '下一步：確認內容');
    expect(find.text('使用此位置'), findsOneWidget);
    expect(prefs.getStringList('foundit_my_item_ids'), isNull);
  });

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
      expect(created['latitude'], 25.033);
      expect(created['longitude'], 121.535);

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

class _FailOnceRepository extends MockItemRepository {
  _FailOnceRepository(SharedPreferences prefs) : super(prefs: prefs);
  bool failUpdate = true;
  @override
  Future<Item?> update(Item item) async {
    if (failUpdate) {
      failUpdate = false;
      throw StateError('network unavailable');
    }
    return super.update(item);
  }

  @override
  Future<bool> delete(String id) async =>
      throw StateError('network unavailable');
}

Future<Item> _seedOwned(
  WidgetTester tester,
  MockItemRepository repo,
  SharedPreferences prefs,
) async {
  final now = DateTime.now();
  final item = await tester.runAsync(
    () => repo.create(
      Item(
        id: '',
        type: ItemType.found,
        title: '原本刊登',
        category: '其他',
        latitude: 22.998,
        longitude: 120.217,
        locationName: '成功大學',
        images: ['assets/images/tote.jpg', 'assets/images/tote.jpg'],
        reward: 500,
        hasReward: true,
        lostAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    ),
  );
  await prefs.setStringList('foundit_my_item_ids', [item!.id]);
  return item;
}
