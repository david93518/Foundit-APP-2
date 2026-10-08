import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_colors.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => AppColors.brightness = Brightness.light);

  test('adaptive colors swap their value with the global brightness', () {
    expect(AppColors.surface.toARGB32(), AppColors.surface.light.toARGB32());
    expect(AppColors.ink == AppColors.textPrimary, isTrue);
    AppColors.brightness = Brightness.dark;
    expect(AppColors.surface.toARGB32(), AppColors.surface.dark.toARGB32());
    // Paper and ink trade places, so text stays readable on every surface.
    expect(AppColors.textPrimary.computeLuminance(), greaterThan(.7));
    expect(AppColors.background.computeLuminance(), lessThan(.05));
    expect(AppColors.onInk.computeLuminance(), lessThan(.05));
    // withValues resolves against the current mode, like a plain Color.
    expect(
      AppColors.primary.withValues(alpha: .5).toARGB32() & 0xFFFFFF,
      AppColors.primary.dark.toARGB32() & 0xFFFFFF,
    );
  });

  test('dark palette keeps text readable on its surfaces', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    AppColors.brightness = Brightness.dark;
    for (final pair in [
      (AppColors.textPrimary, AppColors.surface),
      (AppColors.textSecondary, AppColors.surface),
      (AppColors.textSecondary, AppColors.background),
      (AppColors.primary, AppColors.background),
      (AppColors.primary700, AppColors.primary50),
      (AppColors.onInk, AppColors.ink),
      (AppColors.onPrimary, AppColors.primary),
      (AppColors.ink700, AppColors.ink50),
      (AppColors.reward, AppColors.reward100),
    ]) {
      expect(
        contrast(pair.$1, pair.$2),
        greaterThanOrEqualTo(4.5),
        reason: '${pair.$1.dark} on ${pair.$2.dark}',
      );
    }
  });

  test('theme data carries the right brightness', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('theme mode resolves and persists on this device', () async {
    expect(AppThemeMode.system.resolve(Brightness.dark), Brightness.dark);
    expect(AppThemeMode.light.resolve(Brightness.dark), Brightness.light);
    expect(AppThemeMode.dark.resolve(Brightness.light), Brightness.dark);
    expect(AppThemeMode.fromName('nonsense'), AppThemeMode.system);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), AppThemeMode.system);
    await container.read(themeModeProvider.notifier).set(AppThemeMode.dark);
    expect(prefs.getString(prefThemeMode), 'dark');

    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restored.dispose);
    expect(restored.read(themeModeProvider), AppThemeMode.dark);
  });
}
