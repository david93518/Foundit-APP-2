import 'package:flutter/material.dart';

/// 找得到 — 色彩系統
///
/// 設計哲學：
///  - 主色採柔和 Indigo 取代刺眼純藍
///  - 遺失物／撿到物用珊瑚橙與翡翠綠（暖色系）
///  - 背景使用奶白色而非純白，帶入溫度
///  - 所有顏色皆提供 50～900 深淺階梯以利層次使用
class AppColors {
  AppColors._();

  // ── 品牌主色：Indigo（信任 × 現代） ──
  static const Color primary50 = Color(0xFFEEF2FF);
  static const Color primary100 = Color(0xFFE0E7FF);
  static const Color primary200 = Color(0xFFC7D2FE);
  static const Color primary300 = Color(0xFFA5B4FC);
  static const Color primary400 = Color(0xFF818CF8);
  static const Color primary500 = Color(0xFF6366F1);
  static const Color primary600 = Color(0xFF4F46E5); // 主要品牌色
  static const Color primary700 = Color(0xFF4338CA);
  static const Color primary800 = Color(0xFF3730A3);
  static const Color primary900 = Color(0xFF312E81);

  static const Color primary = primary600;

  // ── 遺失物：珊瑚橙（緊急但不刺眼） ──
  static const Color lost50 = Color(0xFFFFF7ED);
  static const Color lost100 = Color(0xFFFFEDD5);
  static const Color lost200 = Color(0xFFFED7AA);
  static const Color lost400 = Color(0xFFFB923C);
  static const Color lost500 = Color(0xFFF97316);
  static const Color lost600 = Color(0xFFEA580C);
  static const Color lost = lost500;

  // ── 撿到物：翡翠綠（希望與找到感） ──
  static const Color found50 = Color(0xFFECFDF5);
  static const Color found100 = Color(0xFFD1FAE5);
  static const Color found200 = Color(0xFFA7F3D0);
  static const Color found400 = Color(0xFF34D399);
  static const Color found500 = Color(0xFF10B981);
  static const Color found600 = Color(0xFF059669);
  static const Color found = found500;

  // ── 賞金：溫暖金 ──
  static const Color reward50 = Color(0xFFFFFBEB);
  static const Color reward100 = Color(0xFFFEF3C7);
  static const Color reward400 = Color(0xFFFBBF24);
  static const Color reward500 = Color(0xFFF59E0B);
  static const Color reward = reward500;

  // ── 錯誤 ──
  static const Color error50 = Color(0xFFFEF2F2);
  static const Color error500 = Color(0xFFEF4444);
  static const Color error600 = Color(0xFFDC2626);
  static const Color error = error500;

  // ── 中性灰階（暖調，非純灰） ──
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAF9); // 奶白底
  static const Color neutral100 = Color(0xFFF5F5F4);
  static const Color neutral200 = Color(0xFFE7E5E4);
  static const Color neutral300 = Color(0xFFD6D3D1);
  static const Color neutral400 = Color(0xFFA8A29E);
  static const Color neutral500 = Color(0xFF78716C);
  static const Color neutral600 = Color(0xFF57534E);
  static const Color neutral700 = Color(0xFF44403C);
  static const Color neutral800 = Color(0xFF292524);
  static const Color neutral900 = Color(0xFF1C1917);

  // ── 語意色 ──
  static const Color background = neutral50;
  static const Color surface = neutral0;
  static const Color surfaceSoft = neutral100;
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textTertiary = neutral400;
  static const Color divider = neutral200;

  // ── 漸層（App 靈魂） ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB923C), Color(0xFFF97316)],
  );

  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
  );

  static const LinearGradient rewardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );

  /// 物品圖片底部漸層遮罩（讓文字可讀）
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x66000000),
      Color(0xB3000000),
    ],
    stops: [0.4, 0.75, 1.0],
  );
}
