import 'package:flutter/material.dart';

/// FOUND !T — 炭墨、陶土與暖紙。
///
/// 兩種聲音：「撿到」用陶土（primary），「遺失」用炭墨（ink）。
/// 其餘顏色只用於狀態（酬謝、錯誤），不另外加品牌色。
class AppColors {
  AppColors._();
  static const primary50 = Color(0xFFFFF7F1);
  static const primary100 = Color(0xFFFFEEE3);
  static const primary200 = Color(0xFFF9CEB8);
  static const primary300 = Color(0xFFF1AD8A);
  static const primary400 = Color(0xFFEB8C65);
  static const primary500 = Color(0xFFE46B49);
  // Slightly deeper than the logo accent for small text on warm surfaces.
  static const primary600 = Color(0xFFBA4329);
  static const primary700 = Color(0xFFA93D27);
  static const primary800 = Color(0xFF84321F);
  static const primary900 = Color(0xFF622719);
  static const primary = primary600;

  static const lost50 = Color(0xFFFFF5EE);
  static const lost100 = Color(0xFFFFE9D9);
  static const lost200 = Color(0xFFFAD2B2);
  static const lost400 = Color(0xFFEBA777);
  static const lost500 = Color(0xFFC8773D);
  static const lost600 = Color(0xFFAA602B);
  static const lost = lost500;
  static const found50 = primary50;
  static const found100 = primary100;
  static const found200 = primary200;
  static const found400 = primary400;
  static const found500 = primary500;
  static const found600 = primary600;
  static const found = primary600;
  static const reward50 = Color(0xFFFFFBEB);
  static const reward100 = Color(0xFFFEF3C7);
  static const reward400 = Color(0xFFFBBF24);
  static const reward500 = Color(0xFF946114);
  static const reward = reward500;
  static const error50 = Color(0xFFFEF2F2);
  static const error500 = Color(0xFFD34A55);
  static const error600 = Color(0xFFBC3742);
  static const error = error500;

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFFCFAF7);
  static const neutral100 = Color(0xFFF4F2EE);
  static const neutral200 = Color(0xFFE8E4DF);
  static const neutral300 = Color(0xFFD4CFC8);
  static const neutral400 = Color(0xFF76716B);
  static const neutral500 = Color(0xFF706D67);
  static const neutral600 = Color(0xFF65625D);
  static const neutral700 = Color(0xFF4D4C49);
  static const neutral800 = Color(0xFF383B3D);
  static const neutral900 = Color(0xFF282B30);

  /// 炭墨：「遺失／協尋」的聲音，也是主要文字與深色面板的顏色。
  static const ink = neutral900;
  static const ink50 = Color(0xFFF1F0ED);
  static const ink100 = Color(0xFFE3E1DC);
  static const ink700 = neutral700;

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
