import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/item.dart';

/// 遺失物 / 撿到物 的圓角膠囊標籤
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.dense = false});

  final ItemType type;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isLost = type == ItemType.lost;
    final bg = isLost ? AppColors.lost50 : AppColors.found50;
    final fg = isLost ? AppColors.lost600 : AppColors.found600;
    final dot = isLost ? AppColors.lost : AppColors.found;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.allRound,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 6 : 7,
            height: dense ? 6 : 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: dense ? 4 : 6),
          Text(
            type.label,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 賞金標籤
class RewardBadge extends StatelessWidget {
  const RewardBadge({super.key, required this.amount, this.dense = false});

  final int amount;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.rewardGradient,
        borderRadius: AppRadius.allRound,
        boxShadow: [
          BoxShadow(
            color: AppColors.reward.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'NT\$ $amount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
