import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum SnackType { info, success, error, warning }

/// 客製化 SnackBar — 漂浮在底部，圓角 + 陰影 + 彩色左邊條
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackType type = SnackType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final meta = _metaFor(type);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          duration: const Duration(seconds: 3),
          content: Container(
            decoration: BoxDecoration(
              color: AppColors.neutral900,
              borderRadius: AppRadius.allMd,
              boxShadow: AppShadows.lg,
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 4, color: meta.color),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.15),
                        borderRadius: AppRadius.allSm,
                      ),
                      child: Icon(icon ?? meta.icon,
                          color: meta.color, size: 18),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        onAction();
                      },
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          color: meta.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      );
  }

  static void success(BuildContext ctx, String m) =>
      show(ctx, message: m, type: SnackType.success);
  static void error(BuildContext ctx, String m) =>
      show(ctx, message: m, type: SnackType.error);
  static void info(BuildContext ctx, String m) =>
      show(ctx, message: m, type: SnackType.info);
  static void warning(BuildContext ctx, String m) =>
      show(ctx, message: m, type: SnackType.warning);
}

class _SnackMeta {
  final Color color;
  final IconData icon;
  const _SnackMeta(this.color, this.icon);
}

_SnackMeta _metaFor(SnackType t) {
  switch (t) {
    case SnackType.success:
      return const _SnackMeta(AppColors.found, Icons.check_circle_rounded);
    case SnackType.error:
      return const _SnackMeta(AppColors.error, Icons.error_rounded);
    case SnackType.warning:
      return const _SnackMeta(AppColors.reward, Icons.warning_rounded);
    case SnackType.info:
      return const _SnackMeta(AppColors.primary, Icons.info_rounded);
  }
}
