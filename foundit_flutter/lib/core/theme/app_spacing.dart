import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 間距、圓角、陰影 — 統一設計代幣
class AppSpacing {
  AppSpacing._();

  // 基於 4px 網格
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double massive = 64;

  // 頁面水平 padding
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);
}

class AppRadius {
  AppRadius._();

  static const Radius xs = Radius.circular(6);
  static const Radius sm = Radius.circular(10);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(20);
  static const Radius xl = Radius.circular(28);
  static const Radius round = Radius.circular(999);

  static const BorderRadius allXs = BorderRadius.all(xs);
  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius allRound = BorderRadius.all(round);

  /// 底部面板（下圓角為零）
  static const BorderRadius topLg = BorderRadius.only(
    topLeft: lg,
    topRight: lg,
  );
  static const BorderRadius topXl = BorderRadius.only(
    topLeft: xl,
    topRight: xl,
  );
}

/// 柔和、多層次的陰影系統（模擬 iOS 層次感）
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 彩色陰影 — 為按鈕或重要元件加上品牌色光暈
  static List<BoxShadow> colored(Color color, {double opacity = 0.3, double blur = 20}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> primary = colored(AppColors.primary, opacity: 0.35);
  static List<BoxShadow> lost = colored(AppColors.lost, opacity: 0.3);
  static List<BoxShadow> found = colored(AppColors.found, opacity: 0.3);
}
