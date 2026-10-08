import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 圓形 Emoji 分類按鈕（首頁橫向滾動用）
class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.meta,
    required this.onTap,
    this.selected = false,
    this.count = 0,
  });

  final CategoryMeta meta;
  final VoidCallback onTap;
  final bool selected;

  /// 該分類目前待找數量；> 0 時會在右上角秀紅點徽章
  final int count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius: AppRadius.allLg,
                    boxShadow: selected ? AppShadows.primary : AppShadows.xs,
                    border: Border.all(
                      color: selected ? Colors.transparent : AppColors.divider,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(meta.emoji, style: const TextStyle(fontSize: 30)),
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(11),
                        ),
                        border: Border.all(
                          color: AppColors.background,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55F97316),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              meta.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
