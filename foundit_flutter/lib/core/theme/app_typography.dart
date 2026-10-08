import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();
  static const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -1.5,
    ),
    displayMedium: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -1,
    ),
    displaySmall:
        TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.3),
    headlineLarge:
        TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.4),
    headlineMedium:
        TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.4),
    headlineSmall:
        TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
    titleLarge:
        TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
    titleMedium:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
    titleSmall:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
    bodyLarge: TextStyle(fontSize: 16, height: 1.7),
    bodyMedium: TextStyle(fontSize: 14, height: 1.65),
    bodySmall:
        TextStyle(fontSize: 12, height: 1.6, color: AppColors.textSecondary),
    labelLarge:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
    labelMedium:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
    labelSmall:
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.5),
  );
}
