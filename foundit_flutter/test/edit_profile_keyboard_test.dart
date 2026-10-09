import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/user.dart';
import 'package:foundit/data/repositories/auth_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/profile/edit_profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 回歸：iPhone 上點了「顯示名稱」後，鍵盤沒有收起鍵、蓋住下方的儲存按鈕，
// 使用者既收不起鍵盤也存不了檔。

const _nameKey = ValueKey('profile-edit-name');
const _bioKey = ValueKey('profile-edit-bio');
const _scrollKey = ValueKey('profile-edit-scroll');
const _saveBarKey = ValueKey('profile-edit-save-bar');
const _reserved = '這個名稱保留給 FOUND !T 官方使用，請換一個';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets('tapping outside a field dismisses the keyboard', (tester) async {
    await _mount(tester);
    await _focus(tester, _nameKey);
    _keyboard(tester, 336);
    await tester.pumpAndSettle();

    // 固定的標題列與表單裡的空白處都算「欄位以外」。
    await tester.tap(find.text('編輯個人檔案'));
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, _nameKey), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await _focus(tester, _nameKey);
    await tester.tap(find.text('體驗模式：變更只保存在此裝置。'));
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, _nameKey), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next moves from the name to the bio; dragging dismisses', (
    tester,
  ) async {
    await _mount(tester);
    await _focus(tester, _nameKey);
    final name = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(_nameKey),
        matching: find.byType(TextField),
      ),
    );
    expect(name.textInputAction, TextInputAction.next);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, _nameKey), isFalse);
    expect(_hasFocus(tester, _bioKey), isTrue);

    _keyboard(tester, 400);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(_scrollKey), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(_hasFocus(tester, _bioKey), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  for (final device in [
    (name: 'iPhone 15', size: const Size(390, 844), keyboard: 336.0),
    (name: 'iPhone SE', size: const Size(375, 667), keyboard: 300.0),
    (name: 'landscape', size: const Size(844, 390), keyboard: 200.0),
  ]) {
    testWidgets(
      'save stays reachable with the keyboard open on ${device.name}',
      (tester) async {
        final session = await _mount(tester, size: device.size);
        await _focus(tester, _nameKey);
        await tester.enterText(find.byKey(_nameKey), '鍵盤開著也能存');
        _keyboard(tester, device.keyboard);
        await tester.pumpAndSettle();
        expect(_hasFocus(tester, _nameKey), isTrue);

        // 頂端的儲存與底部按鈕同名，鍵盤開著時就在鍵盤上方、點得到。
        final bar = find.byKey(_saveBarKey);
        expect(
          find.descendant(of: bar, matching: find.text('儲存變更')),
          findsOneWidget,
        );
        expect(bar.hitTestable(), findsOneWidget);
        final rect = tester.getRect(bar);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          rect.bottom,
          lessThanOrEqualTo(device.size.height - device.keyboard),
        );
        // 聚焦的欄位也被捲到鍵盤上方。
        expect(
          tester.getRect(find.byKey(_nameKey)).top,
          lessThan(device.size.height - device.keyboard),
        );

        await tester.tap(bar);
        await tester.pumpAndSettle();
        expect(find.text('已返回個人頁'), findsOneWidget);
        expect(
          (await session.read(authRepositoryProvider).cachedUser())?.name,
          '鍵盤開著也能存',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a rejected name shows the server message, not a generic one', (
    tester,
  ) async {
    final session = await _mount(tester, rejectNames: true);
    await _focus(tester, _nameKey);
    await tester.enterText(find.byKey(_nameKey), 'FOUND !T 官方');
    _keyboard(tester, 336);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_saveBarKey));
    await tester.pumpAndSettle();

    expect(find.text(_reserved), findsOneWidget);
    expect(find.text('暫時無法儲存。你的修改已保留，請稍後再試。'), findsNothing);
    expect(find.text('已返回個人頁'), findsNothing);
    expect(
      find.descendant(of: find.byKey(_saveBarKey), matching: find.text('重試儲存')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(_nameKey)).controller!.text,
      'FOUND !T 官方',
    );
    expect(
      (await session.read(authRepositoryProvider).cachedUser())?.name,
      '原本名字',
    );
    expect(tester.takeException(), isNull);
  });
}

bool _hasFocus(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

Future<void> _focus(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  expect(_hasFocus(tester, key), isTrue);
  expect(tester.testTextInput.isVisible, isTrue);
}

void _keyboard(WidgetTester tester, double height) =>
    tester.view.viewInsets = FakeViewPadding(bottom: height);

/// 伺服器拒絕保留名稱：400 `{message}`，與後端格式相同。
class _RejectingAuth extends MockAuthRepository {
  _RejectingAuth(super.prefs);

  @override
  Future<AppUser?> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  }) async {
    final request = RequestOptions(path: '/users/me', method: 'PATCH');
    throw DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: request,
        statusCode: 400,
        data: {'success': false, 'statusCode': 400, 'message': _reserved},
      ),
    );
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool rejectNames = false,
}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefUserId: 'keyboard-test-user',
    AppConstants.prefUserName: '原本名字',
    AppConstants.prefUserAvatar: '',
    AppConstants.prefIsLoggedIn: true,
    'user_bio': '原本介紹',
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      useMockProvider.overrideWithValue(true),
      if (rejectNames)
        authRepositoryProvider.overrideWithValue(_RejectingAuth(prefs)),
    ],
  );
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('已返回個人頁')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
