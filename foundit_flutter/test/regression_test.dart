import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/mock/mock_items.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/item/item_detail_screen.dart';
import 'package:foundit/presentation/screens/main_shell.dart';
import 'package:foundit/presentation/widgets/foundit_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('concurrent bookmark actions retain both items', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final saved = container.read(savedItemsProvider.notifier);

    await Future.wait([saved.toggle('m1'), saved.toggle('m2')]);

    expect(container.read(savedItemsProvider), unorderedEquals(['m1', 'm2']));
    expect(prefs.getBool('bookmark:guest:m1'), isTrue);
    expect(prefs.getBool('bookmark:guest:m2'), isTrue);
  });

  for (final viewport in [
    (size: const Size(1440, 768), top: 0.0, name: 'short desktop'),
    (size: const Size(390, 844), top: 59.0, name: 'mobile with top inset'),
  ]) {
    testWidgets('shell fits ${viewport.name}', (tester) async {
      _setViewport(tester, viewport.size, top: viewport.top);
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_app(
        prefs,
        const MainShell(location: '/home', child: SizedBox.expand()),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (viewport.top == 0) {
        await tester.ensureVisible(find.byTooltip('QR 防丟牌'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('contact sheet remains usable above the mobile keyboard',
      (tester) async {
    _setViewport(tester, const Size(390, 700));
    addTearDown(tester.view.resetViewInsets);
    final prefs = await SharedPreferences.getInstance();
    final item = MockItems.items.firstWhere(
      (item) => item.type == ItemType.found && item.status == ItemStatus.active,
    );
    await tester.pumpWidget(_app(prefs, ItemDetailScreen(item: item)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('這可能是我的'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '內袋有一枚藍色吊飾');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final submit = find.text('建立示範對話');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getBottomRight(submit).dy, lessThanOrEqualTo(400));
  });
}

void _setViewport(WidgetTester tester, Size size, {double top = 0}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: top);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
}

Widget _app(SharedPreferences prefs, Widget child) => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
      ],
      child: MaterialApp(theme: AppTheme.light, home: child),
    );
