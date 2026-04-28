import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 字體階層 — 清晰的視覺層次
///
/// 繁體中文使用 Noto Sans TC；數字／英文搭配 Inter
class AppTypography {
  AppTypography._();

  static TextTheme textTheme = TextTheme(
    // Display — 歡迎語、啟動頁大標
    displayLarge: GoogleFonts.notoSansTc(
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      height: 1.1,
      color: AppColors.textPrimary,
    ),
    displayMedium: GoogleFonts.notoSansTc(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.15,
      color: AppColors.textPrimary,
    ),
    displaySmall: GoogleFonts.notoSansTc(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
      color: AppColors.textPrimary,
    ),

    // Headline — 區塊標題
    headlineLarge: GoogleFonts.notoSansTc(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.25,
      color: AppColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.notoSansTc(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.notoSansTc(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.35,
      color: AppColors.textPrimary,
    ),

    // Title — 卡片標題
    titleLarge: GoogleFonts.notoSansTc(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.notoSansTc(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    titleSmall: GoogleFonts.notoSansTc(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: AppColors.textPrimary,
    ),

    // Body — 內文
    bodyLarge: GoogleFonts.notoSansTc(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.notoSansTc(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
    bodySmall: GoogleFonts.notoSansTc(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: AppColors.textSecondary,
    ),

    // Label — 按鈕、標籤
    labelLarge: GoogleFonts.notoSansTc(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    labelMedium: GoogleFonts.notoSansTc(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.textSecondary,
    ),
    labelSmall: GoogleFonts.notoSansTc(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppColors.textTertiary,
    ),
  );

  /// 數字（賞金、點數、統計）專用 — 等寬、Inter
  static TextStyle number({double size = 24, FontWeight weight = FontWeight.w700, Color? color}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      color: color ?? AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
