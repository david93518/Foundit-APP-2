import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/qr/qr_scan_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  test('QR identifier parsing removes URL query and fragment', () {
    expect(
      parseQrCode('https://foundit.example/qr/1234-abcd?from=tag#contact'),
      '1234-abcd',
    );
    expect(parseQrCode(' https://foundit.example/qr/mock-987/ '), 'mock-987');
    expect(parseQrCode('1234-abcd'), '1234-abcd');
    expect(parseQrCode('/qr/1234-abcd'), '1234-abcd');
    expect(parseQrCode('https://foundit.example/items/1234-abcd'), isNull);
    expect(parseQrCode('https://foundit.example/qr/1234-abcd/another'), isNull);
    expect(parseQrCode('javascript:alert(1)'), isNull);
    expect(parseQrCode('https://foundit.example/qr/%2Fprivate'), isNull);
    expect(parseQrCode(''), isNull);
  });

  testWidgets(
    'scan chrome adapts to available space and provides named 48px controls',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(320, 568), const Size(844, 390)]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          final router = GoRouter(
            initialLocation: '/qr/scan',
            routes: [
              GoRoute(
                path: '/qr/scan',
                builder: (_, __) => const QrScanScreen(
                  cameraPreview: ColoredBox(color: Colors.black),
                ),
              ),
              GoRoute(
                path: '/qr',
                builder: (_, __) => const Scaffold(body: Text('我的防丟牌')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [useMockProvider.overrideWithValue(false)],
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
          expect(find.byType(MobileScanner), findsNothing);
          final frame = tester.getSize(
            find.byKey(const ValueKey('qr-scan-frame')),
          );
          expect(frame.width, greaterThan(0));
          expect(frame.width, lessThan(size.shortestSide));
          expect(frame.width, frame.height);
          for (final key in ['qr-back', 'qr-torch']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          expect(find.byTooltip('手電筒無法使用'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$size text $scale');
          await tester.tap(find.byTooltip('返回防丟牌'));
          await tester.pumpAndSettle();
          expect(find.text('我的防丟牌'), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'long QR result can be read and dismissed at 200% in portrait and landscape',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(320, 568), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => QrScanResultSheet(
                        itemName: '有綠色恐龍吊飾與藍色繩結的深棕色皮革鑰匙包',
                        ownerName: '住在大安森林公園附近的物主陳先生',
                        ownerPhone: '+886 912 345 678（平日下午六點後方便接聽）',
                        onContinue: () => Navigator.pop(sheetContext),
                      ),
                    ),
                    child: const Text('顯示結果'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('顯示結果'));
        await tester.pumpAndSettle();
        expect(find.textContaining('恐龍吊飾'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('繼續掃描'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.widgetWithText(FilledButton, '繼續掃描')).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('繼續掃描'));
        await tester.pumpAndSettle();
        expect(find.byType(QrScanResultSheet), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('direct demo scan route never creates or activates a camera', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [useMockProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const QrScanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.textContaining('體驗模式不會開啟相機'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '返回防丟牌'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
