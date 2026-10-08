import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum SnackType { info, success, error, warning }

/// A keyboard-safe status message. Long text and actions stay scrollable.
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
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.vertical;
    final statusIcon = switch (type) {
      SnackType.success => Icons.check_circle_outline_rounded,
      SnackType.error => Icons.error_outline_rounded,
      SnackType.warning => Icons.warning_amber_rounded,
      SnackType.info => Icons.info_outline_rounded,
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          backgroundColor: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(48, available * .45),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon ?? statusIcon, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        onAction();
                      },
                      child: Text(actionLabel),
                    ),
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
