import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/data/repositories/upload_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/auth/login_screen.dart';
import 'package:foundit/presentation/screens/auth/otp_screen.dart';
import 'package:foundit/presentation/screens/item/add_item_screen.dart';
import 'package:foundit/presentation/screens/item/item_detail_screen.dart';
import 'package:foundit/presentation/screens/qr/qr_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _longItem = Item(
  id: 'accessibility-item',
  type: ItemType.found,
  userId: 'other',
  title: '米白帆布托特包，附有手作刺繡和一個特別長的物品名稱',
  category: '包包',
  description: '內袋有一枚小吊飾，請先核對未公開的特徵，再約定領回方式。',
  locationName: '台北市大安區復興南路一段捷運忠孝復興站地下二樓服務台附近',
  storageLocation: '捷運忠孝復興站站務人員服務台',
  images: ['assets/images/tote.jpg', 'assets/images/wallet.jpg'],
  lostAt: DateTime(2026, 10, 1),
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

Future<GoRouter> _mount(
  WidgetTester tester,
  String path,
  Size size,
  double scale, {
  double keyboard = 0,
  UploadRepository? upload,
  DateTime Function()? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/add',
        builder: (_, __) => const AddItemScreen(type: 'found'),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => ItemDetailScreen(item: _longItem),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (_, state) => ItemDetailRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpScreen(phone: state.extra as String? ?? '0912345678', now: now),
      ),
      GoRoute(path: '/qr', builder: (_, __) => const QrScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('探索物品')),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, __) => const Scaffold(body: Text('示範對話已建立')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
        if (upload != null) uploadRepositoryProvider.overrideWithValue(upload),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _enter(WidgetTester tester, Finder finder, String value) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final loader = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await loader.load();
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetPadding();
    view.resetViewPadding();
    view.resetViewInsets();
  });
  testWidgets('OTP resend deadline gates the action and resets after resend', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 4, 12);
    await _mount(tester, '/otp', const Size(390, 844), 1.3, now: () => now);
    TextButton resend() => tester.widget<TextButton>(
      find.ancestor(
        of: find.textContaining('取得驗證碼').last,
        matching: find.byType(TextButton),
      ),
    );
    expect(resend().onPressed, isNull);
    now = now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1 秒後可重新取得驗證碼'), findsOneWidget);
    expect(resend().onPressed, isNull);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('重新取得驗證碼'), findsOneWidget);
    expect(resend().onPressed, isNotNull);
    await _tap(tester, find.text('重新取得驗證碼'));
    expect(find.text('體驗驗證已準備好，輸入 123456 即可。'), findsOneWidget);
    expect(find.text('60 秒後可重新取得驗證碼'), findsOneWidget);
    expect(resend().onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(768, 1024),
    Size(844, 390),
    Size(1440, 900),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'forms and detail fit ${size.width}x${size.height} at $scale text',
        (tester) async {
          for (final path in ['/add', '/detail', '/login', '/otp', '/qr']) {
            await _mount(tester, path, size, scale);
            expect(
              tester.takeException(),
              isNull,
              reason: '$path at $size / $scale',
            );
            // Dispose timers/providers between independent surfaces.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }

  for (final size in [Size(320, 568), Size(844, 390)]) {
    testWidgets(
      'publish steps, choices and keyboard remain usable at $size large text',
      (tester) async {
        await _mount(tester, '/add', size, 2);
        await _tap(tester, find.text('下一步：地點與時間'));
        expect(find.text('請填寫物品名稱。'), findsOneWidget);
        await _enter(
          tester,
          find.byKey(const ValueKey('publish-title')),
          _longItem.title,
        );
        await _tap(tester, find.text('包包/背包'));
        await _tap(tester, find.text('下一步：地點與時間'));
        expect(find.text('2 / 3'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _enter(
          tester,
          find.byKey(const ValueKey('publish-location')),
          _longItem.locationName,
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await _tap(tester, find.text('已交給店家或站務人員'));
        await _enter(
          tester,
          find.byKey(const ValueKey('publish-storage')),
          _longItem.storageLocation,
        );
        final now = DateTime.now();
        await _tap(
          tester,
          find.text('${now.year} 年 ${now.month} 月 ${now.day} 日'),
        );
        expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .lastDate,
          DateUtils.dateOnly(now),
        );
        await _tap(tester, find.text('取消'));
        await _tap(
          tester,
          find.text('${now.year} 年 ${now.month} 月 ${now.day} 日'),
        );
        await _tap(tester, find.text('確認'));
        await _tap(tester, find.text('下一步：確認內容'));
        expect(find.text('3 / 3'), findsOneWidget);
        await _tap(tester, find.text('修改物品'));
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('publish-title')),
              )
              .controller!
              .text,
          _longItem.title,
        );
        await _tap(tester, find.text('下一步：地點與時間'));
        await _tap(tester, find.text('下一步：確認內容'));
        await _tap(tester, find.text('上一步'));
        expect(find.text('2 / 3'), findsOneWidget);
      },
    );

    testWidgets(
      'login validates, normalizes phone and OTP returns to origin at $size',
      (tester) async {
        final router = await _mount(tester, '/home', size, 2);
        var returned = false;
        router.push<bool>('/login').then((ok) => returned = ok == true);
        await tester.pumpAndSettle();
        await _tap(tester, find.text('體驗手機驗證'));
        expect(find.text('請輸入 09 開頭的 10 位手機號碼'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await _enter(tester, find.byType(TextFormField), '+886 912-345-678');
        tester.view.viewInsets = const FakeViewPadding();
        await _tap(tester, find.text('體驗手機驗證'));
        expect(find.textContaining('手機號碼 0912345678'), findsOneWidget);
        final confirm = find.widgetWithText(FilledButton, '完成體驗登入');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        await _enter(tester, find.byType(TextField), '123456');
        await _tap(tester, find.text('完成體驗登入'));
        expect(returned, isTrue);
        expect(router.routeInformationProvider.value.uri.path, '/home');
      },
    );

    testWidgets(
      'detail save, photos and contact sheet work at $size large text',
      (tester) async {
        await _mount(tester, '/detail', size, 2);
        await _tap(tester, find.byTooltip('收藏物品'));
        expect(find.byTooltip('取消收藏'), findsOneWidget);
        await _tap(tester, find.byTooltip('取消收藏'));
        await _tap(tester, find.bySemanticsLabel('查看第 2 張照片'));
        expect(find.text('2 / 2'), findsOneWidget);
        await _tap(tester, find.text('這可能是我的'));
        await _tap(tester, find.text('建立示範對話'));
        expect(find.text('請填寫至少 4 個字，方便對方核對。'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await _enter(tester, find.byType(TextFormField), '內袋有藍色吊飾');
        await _tap(tester, find.text('建立示範對話'));
        expect(find.text('示範對話已建立'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'QR create, switch, cancel delete and remove work at $size large text',
      (tester) async {
        await _mount(tester, '/qr', size, 2);
        await _tap(tester, find.text('新增示範防丟牌'));
        await _tap(tester, find.text('建立示範 QR'));
        expect(find.text('請輸入物品名稱'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await _enter(tester, find.byType(TextFormField).first, '每天帶出門的米白帆布托特包');
        await _tap(tester, find.text('建立示範 QR'));
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(find.text('每天帶出門的米白帆布托特包'), findsWidgets);
        await _tap(tester, find.text('新增'));
        await _enter(tester, find.byType(TextFormField).first, '鑰匙');
        await _tap(tester, find.text('建立示範 QR'));
        await _tap(tester, find.text('每天帶出門的米白帆布托特包').last);
        await _tap(tester, find.byTooltip('移除 每天帶出門的米白帆布托特包'));
        await _tap(tester, find.text('保留'));
        await _tap(tester, find.byTooltip('移除 每天帶出門的米白帆布托特包'));
        await _tap(tester, find.text('移除防丟牌'));
        expect(find.text('每天帶出門的米白帆布托特包'), findsNothing);
        expect(find.text('鑰匙'), findsWidgets);
      },
    );
  }

  testWidgets(
    'photo source/remove, upload retry and form choices preserve the draft',
    (tester) async {
      final upload = _RetryUpload();
      await _mount(tester, '/add', const Size(390, 844), 1.3, upload: upload);
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final pickedSources = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'pickImage') return null;
            pickedSources.add((call.arguments as Map)['source'] as int);
            return File('assets/images/tote.jpg').absolute.path;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      Future<void> pick(String source) async {
        await tester.ensureVisible(find.text('新增照片'));
        // ensureVisible only schedules the scroll; lay out before tapping.
        await tester.pumpAndSettle();
        await tester.tap(find.text('新增照片'));
        // The busy spinner intentionally runs while the source sheet is open.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // The native picker is replaced at its platform boundary; bytes are read
        // from the bundled real image. Native permission UI needs device testing.
        await tester.tap(find.text(source));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (
          var attempt = 0;
          attempt < 10 && find.text('讀取中…').evaluate().isNotEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await pick('從相簿選擇');
      expect(find.byTooltip('移除照片'), findsOneWidget);
      await _tap(tester, find.byTooltip('移除照片'));
      expect(find.byTooltip('移除照片'), findsNothing);
      await pick('拍攝照片');
      await pick('從相簿選擇');
      expect(pickedSources, [1, 0, 1]);
      await _tap(tester, find.text('我遺失了物品'));
      await _tap(tester, find.text('我撿到了物品'));
      await _enter(
        tester,
        find.byKey(const ValueKey('publish-title')),
        '上傳重試帆布包',
      );
      await _tap(tester, find.text('包包/背包'));
      await _tap(tester, find.text('白色'));
      await _tap(tester, find.text('白色'));
      await _tap(tester, find.text('棕色'));
      await _enter(tester, find.byType(TextFormField).last, '內袋有手作刺繡');
      await _tap(tester, find.text('下一步：地點與時間'));
      await _enter(
        tester,
        find.byKey(const ValueKey('publish-location')),
        '台北市中山站',
      );
      await _tap(tester, find.text('已交給警察機關'));
      await _enter(
        tester,
        find.byKey(const ValueKey('publish-storage')),
        '中山一派出所',
      );
      await _tap(tester, find.text('下一步：確認內容'));
      await tester.ensureVisible(find.text('我已閱讀並同意刊登規範'));
      await _tap(tester, find.text('我已閱讀並同意刊登規範'));
      await _tap(tester, find.text('建立體驗刊登'));
      expect(find.text('第 2 張照片上傳失敗。資料已保留，請檢查連線後重試。'), findsOneWidget);
      expect(upload.attempts, 2);
      await _tap(tester, find.text('建立體驗刊登'));
      expect(
        upload.attempts,
        3,
        reason: 'the first successful upload is reused',
      );
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('foundit_my_item_ids')!;
      expect(ids, hasLength(1));
      final data =
          jsonDecode(prefs.getString('foundit_demo_items_v1')!) as List;
      final saved = data.singleWhere((row) => row['id'] == ids.single) as Map;
      expect(saved['images'], hasLength(2));
      expect(saved['color'], '棕色');
      expect(saved['description'], '內袋有手作刺繡');
      expect(saved['handedToPolice'], isTrue);
    },
  );
}

class _RetryUpload extends MockUploadRepository {
  int attempts = 0;
  @override
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  }) async {
    attempts++;
    if (attempts == 2) return null;
    return super.uploadImageBytes(
      bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
