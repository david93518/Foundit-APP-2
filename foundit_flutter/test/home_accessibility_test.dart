import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/core/theme/app_colors.dart';
import 'package:foundit/core/utils/app_snackbar.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/items_provider.dart';
import 'package:foundit/presentation/screens/home/home_screen.dart';
import 'package:foundit/presentation/screens/main_shell.dart';
import 'package:foundit/presentation/widgets/foundit_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GoRouter> mount(
  WidgetTester tester,
  Size size,
  double scale, {
  bool offline = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (_, s, child) =>
            MainShell(location: s.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          for (final route in ['map', 'chats', 'profile', 'saved', 'my-items'])
            GoRoute(
              path: '/$route',
              builder: (_, __) => Center(child: Text('route:$route')),
            ),
        ],
      ),
      GoRoute(
        path: '/add/:type',
        builder: (_, s) =>
            Scaffold(body: Text('publish:${s.pathParameters['type']}')),
      ),
      GoRoute(
        path: '/qr',
        builder: (_, __) => const Scaffold(body: Text('route:qr')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        if (offline)
          itemsProvider.overrideWith((ref, filter) async {
            throw Exception('offline');
          }),
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
  return router;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });
  testWidgets(
    'offline pull-to-refresh completes and retains the retry action',
    (tester) async {
      await mount(tester, const Size(320, 568), 2, offline: true);
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await expectLater(indicator.onRefresh(), completes);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final retry = find.text('重新載入');
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'brand text colors retain readable contrast on their actual surfaces',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      for (final pair in [
        (AppColors.primary, Colors.white),
        (AppColors.primary, AppColors.primary50),
        (AppColors.primary, AppColors.primary100),
        (AppColors.reward, AppColors.surface),
        (AppColors.textSecondary, AppColors.surface),
        (AppColors.textTertiary, AppColors.background),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    },
  );
  testWidgets(
    'visible home controls have accessible labels and 48px tap targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester, const Size(390, 844), 1);
      try {
        final tooltips = <String>{};
        void collect(SemanticsNode node) {
          final tooltip = node.getSemanticsData().tooltip;
          if (tooltip.isNotEmpty) tooltips.add(tooltip);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(
          tester
              .binding
              .renderViews
              .single
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        expect(tooltips, containsAll(['QR 防丟牌', '我的收藏']));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'short screens keep publishing reachable without covering items',
    (tester) async {
      await mount(tester, const Size(320, 568), 1);
      expect(find.byType(FloatingActionButton), findsNothing);
      final publish = find.byTooltip('刊登物品');
      expect(publish.hitTestable(), findsOneWidget);
      expect(tester.getSize(publish).height, greaterThanOrEqualTo(48));
      // The publish button sits in the docked bar below the scrolling
      // content, so it never floats over an item card.
      final content = tester.getRect(find.byType(SingleChildScrollView).first);
      expect(tester.getRect(publish).top, greaterThanOrEqualTo(content.bottom));
      await tester.tap(publish);
      await tester.pumpAndSettle();
      await tester.tap(find.text('我撿到了物品'));
      await tester.pumpAndSettle();
      expect(find.text('publish:found'), findsOneWidget);
    },
  );
  testWidgets('long status message and action fit above a landscape keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    var acted = false;
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              screen = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    AppSnackbar.show(
      screen,
      message: '網路暫時中斷，輸入的內容已保留，請稍後再試一次。',
      actionLabel: '重新嘗試',
      onAction: () => acted = true,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('重新嘗試'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新嘗試'));
    await tester.pumpAndSettle();
    expect(acted, isTrue);
    expect(tester.takeException(), isNull);
  });
  for (final sample in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.3),
    (const Size(390, 844), 2.0),
    (const Size(844, 390), 2.0),
    (const Size(768, 1024), 2.0),
    (const Size(1440, 900), 2.0),
  ]) {
    testWidgets(
      'home shell ${sample.$1.width.toInt()}x${sample.$1.height.toInt()} text ${sample.$2}',
      (tester) async {
        await mount(tester, sample.$1, sample.$2);
        expect(tester.takeException(), isNull);
        expect(find.byType(FoundItemCard), findsNWidgets(8));
        await tester.ensureVisible(find.byType(FoundItemCard).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'large text filters and publishing sheet work in short landscape',
    (tester) async {
      await mount(tester, const Size(844, 390), 2);
      final filter = find.byTooltip('篩選');
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('最近 7 天'));
      await tester.tap(find.text('最近 7 天'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('最近 7 天'), findsOneWidget);
      final publish = find.byTooltip('刊登物品');
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('我撿到了物品'));
      await tester.tap(find.text('我撿到了物品'));
      await tester.pumpAndSettle();
      expect(find.text('publish:found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text search, clear, type and category controls update results',
    (tester) async {
      await mount(tester, const Size(320, 568), 2);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'airpods');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(FoundItemCard), findsOneWidget);
      await tester.tap(find.byTooltip('清除關鍵字'));
      await tester.pumpAndSettle();
      expect(find.byType(FoundItemCard), findsNWidgets(8));
      await tester.ensureVisible(find.text('在找的'));
      await tester.tap(find.text('在找的'));
      await tester.pumpAndSettle();
      expect(find.byType(FoundItemCard), findsNWidgets(3));
      await tester.ensureVisible(find.text('撿到的'));
      await tester.tap(find.text('撿到的'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('category-錢包'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-錢包')));
      await tester.pumpAndSettle();
      expect(find.byType(FoundItemCard), findsOneWidget);
      expect(find.text('棕色短夾'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'city menu and all bottom navigation destinations remain operable',
    (tester) async {
      final router = await mount(tester, const Size(390, 844), 1.3);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      // 示範資料在新北市有協尋物品，選一個沒有刊登的縣市驗證空狀態。
      await tester.ensureVisible(find.text('桃園市').last);
      await tester.tap(find.text('桃園市').last);
      await tester.pumpAndSettle();
      expect(find.byType(FoundItemCard), findsNothing);
      expect(find.text('還沒有符合的物品'), findsOneWidget);
      for (final destination in [
        ('地圖', 'map'),
        ('訊息', 'chats'),
        ('我的', 'profile'),
        ('首頁', 'home'),
      ]) {
        await tester.tap(find.text(destination.$1).last);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/${destination.$2}',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
