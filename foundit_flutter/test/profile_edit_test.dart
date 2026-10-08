import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/repositories/upload_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/profile/edit_profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _nameKey = ValueKey('profile-edit-name');
const _bioKey = ValueKey('profile-edit-bio');
const _saveKey = ValueKey('profile-edit-save');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets('name and bio save and survive repository recreation', (
    tester,
  ) async {
    final session = await _mount(tester);
    await _edit(tester, _nameKey, '新的顯示名稱');
    await _edit(tester, _bioKey, '喜歡散步，也幫忙留意失物。');
    await _save(tester);
    expect(find.text('已返回個人頁'), findsOneWidget);
    final restored = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(session.prefs),
        useMockProvider.overrideWithValue(true),
      ],
    );
    addTearDown(restored.dispose);
    final user = await restored.read(authRepositoryProvider).cachedUser();
    expect(user?.name, '新的顯示名稱');
    expect(user?.bio, '喜歡散步，也幫忙留意失物。');
  });

  testWidgets('existing bio can be cleared', (tester) async {
    final session = await _mount(tester);
    await _edit(tester, _bioKey, '');
    await _save(tester);
    expect(
      (await session.container.read(authRepositoryProvider).cachedUser())?.bio,
      isEmpty,
    );
  });

  testWidgets(
    'guest receives a working login entry instead of editable fields',
    (tester) async {
      await _mount(tester, guest: true);
      expect(find.byKey(_nameKey), findsNothing);
      await tester.tap(find.text('前往登入'));
      await tester.pumpAndSettle();
      expect(find.text('登入頁'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel preserves the saved profile and asks before discarding', (
    tester,
  ) async {
    final session = await _mount(tester);
    await _edit(tester, _nameKey, '尚未儲存');
    await tester.ensureVisible(find.byTooltip('取消編輯'));
    await tester.tap(find.byTooltip('取消編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(_nameKey)).controller!.text,
      '尚未儲存',
    );
    await tester.tap(find.byTooltip('取消編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄修改'));
    await tester.pumpAndSettle();
    expect(find.text('已返回個人頁'), findsOneWidget);
    expect(
      (await session.container.read(authRepositoryProvider).cachedUser())?.name,
      '原本名字',
    );
  });

  for (final viewport in [
    (
      name: '320px with 200% text',
      size: const Size(320, 568),
      scale: 2.0,
      keyboard: 0.0,
    ),
    (
      name: 'landscape with keyboard',
      size: const Size(844, 390),
      scale: 1.0,
      keyboard: 300.0,
    ),
  ]) {
    testWidgets('profile editing remains usable at ${viewport.name}', (
      tester,
    ) async {
      await _mount(tester, size: viewport.size, scale: viewport.scale);
      await _edit(tester, _nameKey, '小螢幕也能編輯');
      await _edit(tester, _bioKey, '保留完整的輸入與操作。');
      tester.view.viewInsets = FakeViewPadding(bottom: viewport.keyboard);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_saveKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byKey(_saveKey)).dy,
        lessThan(viewport.size.height - viewport.keyboard),
      );
      await _save(tester);
      expect(find.text('已返回個人頁'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed avatar upload retains the entire draft and retries bytes',
    (tester) async {
      final upload = _FailOnceUpload();
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final session = await _mount(tester, upload: upload, pickedBytes: png);
      await tester.tap(find.byKey(const ValueKey('profile-edit-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('從相簿選擇'));
      await tester.pumpAndSettle();
      await _edit(tester, _nameKey, '照片上傳中的名字');
      await _edit(tester, _bioKey, '失敗後保留這段內容。');
      await _save(tester);
      expect(upload.calls, 1);
      expect(find.text('照片上傳失敗。修改與照片已保留，請重試儲存。'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(_nameKey)).controller!.text,
        '照片上傳中的名字',
      );
      expect(
        tester.widget<TextFormField>(find.byKey(_bioKey)).controller!.text,
        '失敗後保留這段內容。',
      );
      expect(
        (await session.container.read(authRepositoryProvider).cachedUser())
            ?.name,
        '原本名字',
      );
      await _save(tester);
      expect(upload.calls, 2);
      final saved = await session.container
          .read(authRepositoryProvider)
          .cachedUser();
      expect(saved?.name, '照片上傳中的名字');
      expect(saved?.bio, '失敗後保留這段內容。');
      expect(
        base64Decode(saved!.avatarUrl.split(',').last),
        orderedEquals(png),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<({ProviderContainer container, SharedPreferences prefs})> _mount(
  WidgetTester tester, {
  bool guest = false,
  Size size = const Size(390, 844),
  double scale = 1,
  UploadRepository? upload,
  Uint8List? pickedBytes,
}) async {
  SharedPreferences.setMockInitialValues(
    guest
        ? {}
        : {
            AppConstants.prefUserId: 'profile-test-user',
            AppConstants.prefUserName: '原本名字',
            AppConstants.prefUserAvatar: '',
            AppConstants.prefIsLoggedIn: true,
            'user_bio': '原本介紹',
          },
  );
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      useMockProvider.overrideWithValue(true),
      if (upload != null) uploadRepositoryProvider.overrideWithValue(upload),
    ],
  );
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (_, __) => EditProfileScreen(
          pickAvatar: pickedBytes == null
              ? null
              : (_) async => XFile.fromData(
                  pickedBytes,
                  name: 'avatar.png',
                  mimeType: 'image/png',
                ),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('已返回個人頁')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('登入頁')),
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
  return (container: container, prefs: prefs);
}

Future<void> _edit(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_saveKey));
  await tester.tap(find.byKey(_saveKey));
  await tester.pumpAndSettle();
}

class _FailOnceUpload extends MockUploadRepository {
  int calls = 0;
  @override
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  }) async {
    calls++;
    if (calls == 1) return null;
    return super.uploadImageBytes(
      bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
