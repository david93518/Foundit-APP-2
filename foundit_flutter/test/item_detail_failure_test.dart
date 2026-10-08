import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/data/repositories/item_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/item/item_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DetailRepository extends MockItemRepository {
  _DetailRepository({this.missing = false});
  final bool missing;
  int requests = 0;

  @override
  Future<Item?> detail(String id) async {
    requests++;
    if (missing) return null;
    if (requests == 1) throw StateError('API unavailable');
    return Item(
      id: id,
      type: ItemType.found,
      title: '重新載入成功的帆布包',
      category: '包包/背包',
      lostAt: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
  }
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _DetailRepository repository,
) async {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/item/test',
    routes: [
      GoRoute(
        path: '/item/:id',
        builder: (_, state) => ItemDetailRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('探索物品')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        itemRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapAction(WidgetTester tester, String text) async {
  final action = find.widgetWithText(FilledButton, text);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  expect(action.hitTestable(), findsOneWidget);
  final rect = tester.getRect(action);
  expect(rect.top, greaterThanOrEqualTo(80));
  expect(rect.bottom, lessThanOrEqualTo(366));
  expect(rect.height, greaterThanOrEqualTo(48));
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets(
    'missing item can scroll to and tap explore at landscape 2x text',
    (tester) async {
      final repository = _DetailRepository(missing: true);
      final router = await _mount(tester, repository);
      expect(tester.takeException(), isNull);
      expect(find.text('找不到這件物品'), findsOneWidget);
      await _tapAction(tester, '回到探索');
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('探索物品'), findsOneWidget);
      expect(repository.requests, 1);
    },
  );

  testWidgets(
    'failed item can scroll to retry and load data at landscape 2x text',
    (tester) async {
      final repository = _DetailRepository();
      await _mount(tester, repository);
      expect(tester.takeException(), isNull);
      expect(find.text('物品暫時無法載入'), findsOneWidget);
      await _tapAction(tester, '重試');
      expect(repository.requests, 2);
      expect(find.text('重新載入成功的帆布包'), findsOneWidget);
      expect(find.text('物品暫時無法載入'), findsNothing);
    },
  );
}
