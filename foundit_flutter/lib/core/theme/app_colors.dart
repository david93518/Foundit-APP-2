import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

/// 會跟著亮／暗模式切換的顏色。
///
/// 整個 App 有數百處 `const TextStyle(color: AppColors.x)`；與其改每個呼叫點，
/// 不如讓顏色本身在繪製時才決定值：`Color` 的所有消費者（Paint、文字編碼、
/// lerp）都透過 getter 讀取分量，所以覆寫 getter 就能即時換色。
/// 切換模式時整棵頁面樹會重建（見 app.dart），不會留下舊色。
class AdaptiveColor extends Color {
  const AdaptiveColor(this.light, this.dark) : super(0xFF000000);

  /// 亮色模式的值；疊在照片或地圖等永遠是亮色的表面上時，直接用這個。
  final Color light;
  final Color dark;

  Color get _current => AppColors.isDark ? dark : light;

  @override
  double get a => _current.a;
  @override
  double get r => _current.r;
  @override
  double get g => _current.g;
  @override
  double get b => _current.b;
  @override
  ColorSpace get colorSpace => _current.colorSpace;
}

/// FOUND !T — 炭墨、陶土與暖紙。
///
/// 兩種聲音：「撿到」用陶土（primary），「遺失」用炭墨（ink）。
/// 深色模式把紙變成炭墨、炭墨變成紙，陶土稍微提亮以維持對比。
class AppColors {
  AppColors._();

  /// 由 app.dart 在重建整棵樹之前設定；其他地方只讀。
  static Brightness brightness = Brightness.light;
  static bool get isDark => brightness == Brightness.dark;

  static const primary50 = AdaptiveColor(Color(0xFFFFF7F1), Color(0xFF2A1F1B));
  static const primary100 = AdaptiveColor(Color(0xFFFFEEE3), Color(0xFF362520));
  static const primary200 = AdaptiveColor(Color(0xFFF9CEB8), Color(0xFF573527));
  static const primary300 = AdaptiveColor(Color(0xFFF1AD8A), Color(0xFF7F4A37));
  static const primary400 = AdaptiveColor(Color(0xFFEB8C65), Color(0xFFD9704D));
  static const primary500 = AdaptiveColor(Color(0xFFE46B49), Color(0xFFE8774F));
  // Slightly deeper than the logo accent for small text on warm surfaces.
  static const primary600 = AdaptiveColor(Color(0xFFBA4329), Color(0xFFE8774F));
  static const primary700 = AdaptiveColor(Color(0xFFA93D27), Color(0xFFF0A585));
  static const primary800 = AdaptiveColor(Color(0xFF84321F), Color(0xFFF5C2A8));
  static const primary900 = AdaptiveColor(Color(0xFF622719), Color(0xFFF9D9C8));
  static const primary = primary600;

  /// 放在陶土色上的文字與圖示。深色模式的陶土為了在深底上可讀而提亮，
  /// 所以上面的字改用炭墨，和放在 ink 上的字一致。
  static const onPrimary = AdaptiveColor(Color(0xFFFFFFFF), Color(0xFF1A1C1F));

  static const lost50 = AdaptiveColor(Color(0xFFFFF5EE), Color(0xFF2A2118));
  static const lost100 = AdaptiveColor(Color(0xFFFFE9D9), Color(0xFF3A2C1C));
  static const lost200 = AdaptiveColor(Color(0xFFFAD2B2), Color(0xFF5A4127));
  static const lost400 = AdaptiveColor(Color(0xFFEBA777), Color(0xFFE0A270));
  static const lost500 = AdaptiveColor(Color(0xFFC8773D), Color(0xFFE3A066));
  static const lost600 = AdaptiveColor(Color(0xFFAA602B), Color(0xFFEDB57F));
  static const lost = lost500;
  static const found50 = primary50;
  static const found100 = primary100;
  static const found200 = primary200;
  static const found400 = primary400;
  static const found500 = primary500;
  static const found600 = primary600;
  static const found = primary600;
  static const reward50 = AdaptiveColor(Color(0xFFFFFBEB), Color(0xFF2A2410));
  static const reward100 = AdaptiveColor(Color(0xFFFEF3C7), Color(0xFF3B3114));
  static const reward400 = AdaptiveColor(Color(0xFFFBBF24), Color(0xFFF5C542));
  static const reward500 = AdaptiveColor(Color(0xFF946114), Color(0xFFE8C15A));
  static const reward = reward500;
  static const error50 = AdaptiveColor(Color(0xFFFEF2F2), Color(0xFF331A1C));
  static const error500 = AdaptiveColor(Color(0xFFD34A55), Color(0xFFE8717A));
  static const error600 = AdaptiveColor(Color(0xFFBC3742), Color(0xFFF08A92));
  static const error = error500;

  static const neutral0 = AdaptiveColor(Color(0xFFFFFFFF), Color(0xFF1E2023));
  static const neutral50 = AdaptiveColor(Color(0xFFFCFAF7), Color(0xFF141517));
  static const neutral100 = AdaptiveColor(Color(0xFFF4F2EE), Color(0xFF26292D));
  static const neutral200 = AdaptiveColor(Color(0xFFE8E4DF), Color(0xFF32363B));
  static const neutral300 = AdaptiveColor(Color(0xFFD4CFC8), Color(0xFF4A4F55));
  static const neutral400 = AdaptiveColor(Color(0xFF76716B), Color(0xFF8E8A84));
  static const neutral500 = AdaptiveColor(Color(0xFF706D67), Color(0xFF9C9892));
  static const neutral600 = AdaptiveColor(Color(0xFF65625D), Color(0xFFADA9A2));
  static const neutral700 = AdaptiveColor(Color(0xFF4D4C49), Color(0xFFC9C5BE));
  static const neutral800 = AdaptiveColor(Color(0xFF383B3D), Color(0xFFDAD6CF));
  static const neutral900 = AdaptiveColor(Color(0xFF282B30), Color(0xFFF2F0EB));

  /// 炭墨：「遺失／協尋」的聲音，也是主要文字與深色面板的顏色。
  /// 深色模式下炭墨變成紙色，所以放在炭墨上的文字要用 [onInk]。
  static const ink = neutral900;
  static const ink50 = AdaptiveColor(Color(0xFFF1F0ED), Color(0xFF2B2E33));
  static const ink100 = AdaptiveColor(Color(0xFFE3E1DC), Color(0xFF3A3E44));
  static const ink700 = neutral700;
  static const onInk = AdaptiveColor(Color(0xFFFFFFFF), Color(0xFF1A1C1F));
  static const onInkMuted = AdaptiveColor(Color(0xB3FFFFFF), Color(0xB31A1C1F));

  static const background = neutral50;
  static const surface = neutral0;
  static const surfaceSoft = neutral100;
  static const textPrimary = neutral900;
  static const textSecondary = neutral600;
  static const textTertiary = neutral400;
  static const divider = neutral200;

  static const primaryGradient = LinearGradient(
    colors: [primary500, primary600],
  );
  static const heroGradient = LinearGradient(colors: [primary700, primary500]);
  static const sunsetGradient = LinearGradient(colors: [lost400, lost500]);
  static const mintGradient = LinearGradient(colors: [primary400, primary600]);
  static const rewardGradient = LinearGradient(colors: [reward400, reward500]);
  static const imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x66000000), Color(0xB3000000)],
    stops: [0.4, 0.75, 1.0],
  );
}
