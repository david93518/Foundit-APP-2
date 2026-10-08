import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core_providers.dart';

/// 使用者選擇的外觀：跟隨系統、淺色或深色。保存在此裝置。
enum AppThemeMode {
  system('跟隨系統'),
  light('淺色'),
  dark('深色');

  const AppThemeMode(this.label);
  final String label;

  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => AppThemeMode.system,
  );

  Brightness resolve(Brightness platform) => switch (this) {
    AppThemeMode.system => platform,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };
}

const prefThemeMode = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._prefs)
    : super(AppThemeMode.fromName(_prefs.getString(prefThemeMode)));
  final SharedPreferences _prefs;

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    await _prefs.setString(prefThemeMode, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
      (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider)),
    );
