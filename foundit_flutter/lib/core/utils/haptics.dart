import 'package:flutter/services.dart';

/// 薄薄一層包裝，未來要換掉或禁用整個 App 的觸覺回饋只改這裡
class Haptics {
  Haptics._();

  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> medium() => HapticFeedback.mediumImpact();
  static Future<void> heavy() => HapticFeedback.heavyImpact();
  static Future<void> select() => HapticFeedback.selectionClick();
  static Future<void> success() => HapticFeedback.mediumImpact();
}
