import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/home/home_screen.dart';
import 'package:foundit/presentation/widgets/foundit_ui.dart';

void main() {
  Future<void> home(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(true)
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();
  }

  tearDown(() {});
  testWidgets('home renders at narrow mobile, tablet and desktop widths',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(360, 800),
      const Size(768, 1024),
      const Size(1440, 1000)
    ]) {
      await home(tester, size);
      expect(find.text('探索失物'), findsOneWidget);
      // 預設「全部」，遺失與拾獲物品都看得到。
      expect(find.text('全部'), findsWidgets);
      expect(find.text('撿到的'), findsOneWidget);
      // The first item card starts above the fold: on an 800px-tall phone
      // it sits below the intent cards, search and filters, still visible.
      expect(tester.getTopLeft(find.byType(FoundItemCard).first).dy,
          lessThan(600));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
      'search, no-results, reset and category filters update real results',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await home(tester, const Size(1440, 1100));
    expect(find.byType(FoundItemCard), findsNWidgets(8));
    await tester.enterText(find.byType(TextField), 'airpods');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(FoundItemCard), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在的紫色腳踏車');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('還沒有符合的物品'), findsOneWidget);
    await tester.ensureVisible(find.text('清除篩選').first);
    await tester.tap(find.text('清除篩選').first);
    await tester.pumpAndSettle();
    expect(find.byType(FoundItemCard), findsNWidgets(8));
    await tester.tap(find.text('撿到的'));
    await tester.pumpAndSettle();
    expect(find.byType(FoundItemCard), findsNWidgets(5));
    await tester.ensureVisible(find.byKey(const ValueKey('category-錢包')));
    await tester.tap(find.byKey(const ValueKey('category-錢包')));
    await tester.pumpAndSettle();
    expect(find.byType(FoundItemCard), findsOneWidget);
    expect(find.text('棕色短夾'), findsOneWidget);
  });
  testWidgets('bookmark state persists across provider recreation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    await c.read(savedItemsProvider.notifier).toggle('m1');
    expect(c.read(savedItemsProvider), contains('m1'));
    c.dispose();
    final restored = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(restored.read(savedItemsProvider), contains('m1'));
    await restored.read(savedItemsProvider.notifier).toggle('m1');
    expect(restored.read(savedItemsProvider), isEmpty);
    restored.dispose();
  });
}
