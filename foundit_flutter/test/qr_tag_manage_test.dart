import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/qr_item.dart';
import 'package:foundit/data/repositories/qr_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/qr/qr_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 模擬尚未更新的後端：DELETE 只標記撤銷，GET /qr/items 仍會列出。
class _RevokeOnlyRepository extends MockQrRepository {
  final removed = <String>[];
  @override
  Future<void> remove(String id) async => removed.add(id);
}

/// 後端拒絕更新（例如名稱含電話號碼）時回 400。
class _RejectingRepository extends MockQrRepository {
  @override
  Future<QrItemModel> update(
    String id, {
    required String name,
    String description = '',
  }) async {
    final options = RequestOptions(path: '/qr/items/$id');
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 400,
        data: const {'success': false, 'message': '名稱不可包含電話號碼'},
      ),
    );
  }
}

Future<void> _mount(
  WidgetTester tester,
  QrRepository repository, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        qrRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QrScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _previewName(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('qr-preview-name'))).data!;

Finder _inNote(String text) => find.descendant(
  of: find.byKey(const ValueKey('qr-preview-note')),
  matching: find.text(text),
);

String _field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets(
    'a removed tag leaves the list at once, even if the server still lists it',
    (tester) async {
      final repository = _RevokeOnlyRepository();
      final umbrella = (await tester.runAsync(
        () => repository.generate(name: '藍色雨傘', description: '握把有貼紙'),
      ))!;
      await tester.runAsync(() => repository.generate(name: '家門鑰匙'));
      await _mount(tester, repository);
      expect(find.text('我的防丟牌 · 2'), findsOneWidget);
      // 最新的排在前面；先選取雨傘，確認移除後選取也會清掉。
      expect(_previewName(tester), '家門鑰匙');
      await _tap(tester, find.text('藍色雨傘').last);
      expect(_previewName(tester), '藍色雨傘');

      await _tap(tester, find.byTooltip('移除 藍色雨傘'));
      expect(find.text('移除這張防丟牌？'), findsOneWidget);
      await tester.tap(find.text('移除防丟牌'));
      // 不推進時間：重新載入（200 ms）尚未完成，清單就已經拿掉。
      await tester.pump();
      await tester.pump();
      expect(repository.removed, [umbrella.id]);
      expect(find.text('藍色雨傘'), findsNothing);
      expect(find.text('我的防丟牌 · 1'), findsOneWidget);

      // 重新載入後伺服器仍回傳已撤銷的防丟牌，也不會再出現。
      await tester.pumpAndSettle();
      expect(find.text('藍色雨傘'), findsNothing);
      expect(find.text('我的防丟牌 · 1'), findsOneWidget);
      expect(_previewName(tester), '家門鑰匙');
      expect(find.text('已移除防丟牌'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a removed last tag returns to the empty state', (tester) async {
    final repository = MockQrRepository();
    await tester.runAsync(() => repository.generate(name: '家門鑰匙'));
    await _mount(tester, repository);
    await _tap(tester, find.byTooltip('移除 家門鑰匙'));
    await tester.tap(find.text('移除防丟牌'));
    await tester.pump();
    await tester.pump();
    expect(find.text('家門鑰匙'), findsNothing);
    expect(find.text('從一件重要的小物開始'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('從一件重要的小物開始'), findsOneWidget);
  });

  testWidgets('the preview shows the note and editing updates it in place', (
    tester,
  ) async {
    final repository = MockQrRepository();
    final tag = (await tester.runAsync(
      () => repository.generate(name: '藍色雨傘', description: '握把有貼紙'),
    ))!;
    await _mount(tester, repository);
    expect(_previewName(tester), '藍色雨傘');
    expect(_inNote('備註'), findsOneWidget);
    expect(_inNote('握把有貼紙'), findsOneWidget);

    final edit = find.byTooltip('編輯防丟牌');
    expect(edit, findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('qr-edit'))).height,
      greaterThanOrEqualTo(48),
    );
    await _tap(tester, edit);
    expect(find.text('編輯防丟牌'), findsOneWidget);
    expect(find.text('QR 內容不會改變'), findsOneWidget);
    expect(_field(tester, 'qr-sheet-name'), '藍色雨傘');
    expect(_field(tester, 'qr-sheet-description'), '握把有貼紙');

    await tester.enterText(
      find.byKey(const ValueKey('qr-sheet-name')),
      '黑色長柄傘',
    );
    await tester.enterText(
      find.byKey(const ValueKey('qr-sheet-description')),
      '傘套是格紋',
    );
    await _tap(tester, find.text('儲存變更'));

    expect(find.text('儲存變更'), findsNothing);
    expect(_previewName(tester), '黑色長柄傘');
    expect(_inNote('傘套是格紋'), findsOneWidget);
    expect(find.text('藍色雨傘'), findsNothing);
    expect(find.text('握把有貼紙'), findsNothing);
    expect(find.text('已儲存變更'), findsOneWidget);
    final stored = (await tester.runAsync(repository.listMine))!.single;
    expect(stored.id, tag.id);
    expect(stored.name, '黑色長柄傘');
    expect(stored.description, '傘套是格紋');
    // QR 內容不變，已列印的貼紙照常可用。
    expect(stored.qrCode, tag.qrCode);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit sheet stays usable on a small screen at large text', (
    tester,
  ) async {
    final repository = MockQrRepository();
    await tester.runAsync(
      () => repository.generate(
        name: '每天帶出門的米白帆布托特包',
        description: '提把有一枚綠色吊飾，內袋有藍色拉鍊',
      ),
    );
    await _mount(tester, repository, size: const Size(320, 568), textScale: 2);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('編輯防丟牌'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('qr-sheet-description')),
      '提把有一枚綠色吊飾',
    );
    // 先讓輸入游標的捲動結束，再捲到儲存按鈕。
    await tester.pumpAndSettle();
    await _tap(tester, find.text('儲存變更'));
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('儲存變更'), findsNothing);
    expect(_inNote('提把有一枚綠色吊飾'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty note invites the owner to add one', (tester) async {
    final repository = MockQrRepository();
    await tester.runAsync(() => repository.generate(name: '家門鑰匙'));
    await _mount(tester, repository);
    expect(_inNote('尚未填寫。可以補上顏色、吊飾等特徵，方便辨認。'), findsOneWidget);
    await _tap(tester, find.byTooltip('編輯防丟牌'));
    await tester.enterText(
      find.byKey(const ValueKey('qr-sheet-description')),
      '紅色鑰匙圈',
    );
    await _tap(tester, find.text('儲存變更'));
    expect(_inNote('紅色鑰匙圈'), findsOneWidget);
  });

  testWidgets('a rejected edit shows the server reason and keeps the input', (
    tester,
  ) async {
    final repository = _RejectingRepository();
    await tester.runAsync(() => repository.generate(name: '藍色雨傘'));
    await _mount(tester, repository);
    await _tap(tester, find.byTooltip('編輯防丟牌'));
    await tester.enterText(
      find.byKey(const ValueKey('qr-sheet-name')),
      '藍色雨傘 0912345678',
    );
    await _tap(tester, find.text('儲存變更'));
    expect(find.text('名稱不可包含電話號碼。你的輸入已保留，修改後再試一次。'), findsOneWidget);
    expect(find.text('編輯防丟牌'), findsOneWidget);
    expect(_field(tester, 'qr-sheet-name'), '藍色雨傘 0912345678');
    await _tap(tester, find.byTooltip('關閉'));
    expect(_previewName(tester), '藍色雨傘');
  });

  testWidgets('editing a tag that no longer exists refreshes the list', (
    tester,
  ) async {
    final repository = MockQrRepository();
    await tester.runAsync(() => repository.generate(name: '藍色雨傘'));
    final keys = (await tester.runAsync(
      () => repository.generate(name: '家門鑰匙'),
    ))!;
    await _mount(tester, repository);
    expect(_previewName(tester), '家門鑰匙');
    await _tap(tester, find.byTooltip('編輯防丟牌'));
    // 在別的裝置上移除了：PATCH 會回 404。
    await tester.runAsync(() => repository.remove(keys.id));
    await tester.enterText(find.byKey(const ValueKey('qr-sheet-name')), '備用鑰匙');
    await _tap(tester, find.text('儲存變更'));
    expect(find.text('儲存變更'), findsNothing);
    expect(find.text('這張防丟牌已不存在，清單已重新整理。'), findsOneWidget);
    expect(find.text('家門鑰匙'), findsNothing);
    expect(find.text('我的防丟牌 · 1'), findsOneWidget);
    expect(_previewName(tester), '藍色雨傘');
  });
}
