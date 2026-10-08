import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/app_notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              unread: unread,
              onBack: () => context.pop(),
              onReadAll: () async {
                Haptics.light();
                await ref.read(notificationActionsProvider).markAllRead();
                if (context.mounted) {
                  AppSnackbar.success(context, '已將全部標記為已讀');
                }
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  await ref.read(notificationsProvider.future);
                },
                child: async.when(
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const SkeletonBox(
                      width: double.infinity,
                      height: 76,
                      radius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  error: (e, _) => EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: '載入失敗',
                    description: e.toString(),
                    ctaLabel: '重試',
                    onCta: () => ref.invalidate(notificationsProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: '目前沒有通知',
                        description: '有新訊息或配對結果時，會第一時間通知你',
                      );
                    }
                    return AnimationLimiter(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            AnimationConfiguration.staggeredList(
                              position: i,
                              duration: const Duration(milliseconds: 380),
                              child: SlideAnimation(
                                verticalOffset: 24,
                                child: FadeInAnimation(
                                  child: _NotiCard(
                                    noti: items[i],
                                    onTap: () async {
                                      Haptics.light();
                                      if (!items[i].isRead) {
                                        await ref
                                            .read(notificationActionsProvider)
                                            .markRead(items[i].id);
                                      }
                                      if (!context.mounted) return;
                                      if (items[i].chatId != null) {
                                        context.push(
                                          '/chat/${items[i].chatId}',
                                        );
                                      } else if (items[i].itemId != null) {
                                        context.push(
                                          '/item/${items[i].itemId}',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.onBack,
    required this.onReadAll,
  });
  final int unread;
  final VoidCallback onBack;
  final VoidCallback onReadAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '通知',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              if (unread > 0)
                Text(
                  '$unread 則未讀',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: unread > 0 ? onReadAll : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          child: const Text(
            '全部已讀',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _NotiCard extends StatelessWidget {
  const _NotiCard({required this.noti, required this.onTap});
  final AppNotification noti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !noti.isRead;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allLg,
        side: BorderSide(
          color: unread ? AppColors.primary200 : AppColors.divider,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary50 : AppColors.ink50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(noti.type),
                  color: unread ? AppColors.primary : AppColors.ink700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            noti.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormatter.relative(noti.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: unread
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noti.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationType t) => switch (t) {
    NotificationType.match => Icons.auto_awesome_outlined,
    NotificationType.chat => Icons.chat_bubble_outline_rounded,
    NotificationType.itemUpdate => Icons.inventory_2_outlined,
    NotificationType.system => Icons.info_outline_rounded,
  };
}
