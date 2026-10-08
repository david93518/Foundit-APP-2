import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/item.dart';
import 'type_badge.dart';

/// 大照片式精選卡片（橫向滑動用）
/// 尺寸：240 x 320，圖片佔上方，文字資訊浮在漸層遮罩上
class FeaturedItemCard extends StatelessWidget {
  const FeaturedItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        height: 320,
        decoration: BoxDecoration(
          borderRadius: AppRadius.allLg,
          color: AppColors.surface,
          boxShadow: AppShadows.md,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(tag: 'item_image_${item.id}', child: _buildImage(item)),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.imageScrim),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TypeBadge(type: item.type, dense: true),
                  if (item.hasReward && item.reward > 0)
                    RewardBadge(amount: item.reward, dense: true),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item.locationName.isEmpty
                              ? '未知地點'
                              : item.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatter.relative(item.lostAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表卡片（首頁「最新附近」區塊、搜尋結果）
/// 左圖右文、圓角大、柔和陰影
class ListItemCard extends StatelessWidget {
  const ListItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allLg,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLg,
            boxShadow: AppShadows.sm,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.allMd,
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: _buildImage(item),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TypeBadge(type: item.type, dense: true),
                          const Spacer(),
                          if (item.hasReward && item.reward > 0)
                            RewardBadge(amount: item.reward, dense: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item.locationName.isEmpty
                                  ? '未知地點'
                                  : item.locationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormatter.relative(item.lostAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildImage(Item item) {
  if (item.images.isEmpty) {
    return _EmojiPlaceholder(category: item.category);
  }
  return CachedNetworkImage(
    imageUrl: item.images.first,
    fit: BoxFit.cover,
    placeholder: (_, __) => Shimmer.fromColors(
      baseColor: AppColors.neutral100,
      highlightColor: AppColors.neutral200,
      child: Container(color: AppColors.neutral100),
    ),
    errorWidget: (_, __, ___) => _EmojiPlaceholder(category: item.category),
  );
}

class _EmojiPlaceholder extends StatelessWidget {
  const _EmojiPlaceholder({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final meta = AppConstants.itemCategories.firstWhere(
      (c) => category.contains(c.name) || c.name.contains(category),
      orElse: () => const CategoryMeta('其他', '📦'),
    );
    return Container(
      color: AppColors.neutral100,
      alignment: Alignment.center,
      child: Text(meta.emoji, style: const TextStyle(fontSize: 44)),
    );
  }
}
