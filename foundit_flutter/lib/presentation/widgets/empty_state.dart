import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'gradient_button.dart';

/// 通用空狀態 — 漸層圓形插圖 + 標題 + 說明 + 可選 CTA
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCta,
    this.gradient,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Illustration(icon: icon, gradient: gradient),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                child: GradientButton(
                  label: ctaLabel!,
                  onPressed: onCta!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, this.gradient});
  final IconData icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AppColors.primaryGradient;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary50,
                AppColors.primary100.withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: g,
            boxShadow: AppShadows.primary,
          ),
          child: Icon(icon, color: Colors.white, size: 44),
        ),
        Positioned(
          top: 20,
          right: 30,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary300,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 20,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary400,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
