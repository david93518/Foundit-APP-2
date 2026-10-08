import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/app.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/theme/app_colors.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/theme_provider.dart';
import 'package:foundit/presentation/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AppColors.brightness = Brightness.light);

  testWidgets(
    'switching appearance rebuilds the page tree in the new palette',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        AppConstants.prefAuthToken: 'mock_token_xyz',
        AppConstants.prefUserId: 'u1',
        AppConstants.prefUserName: 'David',
        AppConstants.prefIsLoggedIn: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      MaterialApp appWidget() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FounditApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(AppColors.isDark, isFalse);
      final before = tester.element(find.byType(HomeScreen));
      final routerBefore = appWidget().routerConfig;
      final navBefore = tester.element(find.byType(Navigator).first);
      final lightTitle = tester.renderObject<RenderParagraph>(
        find.text('探索失物'),
      );

      await container.read(themeModeProvider.notifier).set(AppThemeMode.dark);
      await tester.pumpAndSettle();

      expect(AppColors.isDark, isTrue);
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        Brightness.dark,
      );
      // A fresh element means every const text and box was laid out again
      // with dark values instead of keeping light-mode paragraphs around.
      final after = tester.element(find.byType(HomeScreen));
      expect(identical(routerBefore, appWidget().routerConfig), isFalse);
      expect(
        identical(navBefore, tester.element(find.byType(Navigator).first)),
        isFalse,
      );
      expect(identical(before, after), isFalse);
      expect(
        identical(lightTitle, tester.renderObject(find.text('探索失物'))),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      expect(prefs.getString(prefThemeMode), 'dark');
    },
  );
}
