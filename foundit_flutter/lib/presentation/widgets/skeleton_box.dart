import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 通用 Skeleton 區塊（已內建 shimmer）
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius,
  });

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral100,
      highlightColor: AppColors.neutral50,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: radius ?? AppRadius.allXs,
        ),
      ),
    );
  }
}

/// Item card 專用 skeleton（與 FeaturedItemCard / ListItemCard 佈局對齊）
class ItemCardSkeleton extends StatelessWidget {
  const ItemCardSkeleton({super.key, this.isList = true});
  final bool isList;

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.allLg,
          boxShadow: AppShadows.xs,
        ),
        child: Row(
          children: [
            const SkeletonBox(
                width: 96, height: 96, radius: BorderRadius.all(Radius.circular(14))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SkeletonBox(width: 72, height: 20),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: double.infinity, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 140, height: 12),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      SkeletonBox(width: 60, height: 10),
                      SizedBox(width: 10),
                      SkeletonBox(width: 40, height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: double.infinity,
            height: 200,
            radius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 72, height: 20),
                SizedBox(height: 10),
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
