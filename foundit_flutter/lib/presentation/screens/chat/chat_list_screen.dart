import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/chat.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';

/// 聊天列表 — 簡潔現代的對話清單
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _tab = 0;

  /// 0 = 全部、1 = 未讀
  /// 「尋物 / 拾獲」tab 暫時隱藏 — 後端目前不在 chat list 帶 item.type，
  /// 等之後 toMobileChat 補 item_type 欄位再啟用。
  List<Chat> _filter(List<Chat> list) {
    switch (_tab) {
      case 1:
        return list.where((c) => c.unreadCount > 0).toList();
      default:
        return list;
    }
  }

  Future<void> _onRefresh() async {
    Haptics.light();
    ref.invalidate(chatsProvider);
    await ref.read(chatsProvider.future);
    if (!mounted) return;
    AppSnackbar.success(context, '訊息已同步');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            _TabBar(
                selected: _tab, onSelect: (i) => setState(() => _tab = i)),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _onRefresh,
                child: async.when(
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    itemCount: 5,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 24, color: AppColors.divider),
                    itemBuilder: (_, __) => Row(
                      children: [
                        const SkeletonBox(
                          width: 56,
                          height: 56,
                          radius: BorderRadius.all(Radius.circular(28)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonBox(
                                width: double.infinity,
                                height: 14,
                              ),
                              SizedBox(height: 8),
                              SkeletonBox(width: 200, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: '載入失敗',
                          description: e.toString(),
                          ctaLabel: '重新整理',
                          onCta: () => ref.invalidate(chatsProvider),
                        ),
                      ),
                    ],
                  ),
                  data: (all) {
                    final items = _filter(all);
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.5,
                            child: EmptyState(
                              icon: _tab == 1
                                  ? Icons.mark_chat_read_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              title: _tab == 1 ? '沒有未讀訊息' : '還沒有聊天紀錄',
                              description: _tab == 1
                                  ? '都處理完啦！享受片刻寧靜'
                                  : '到首頁看看有趣的物品，主動聯繫對方吧',
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 24, color: AppColors.divider),
                      itemBuilder: (_, i) => _ChatRow(chat: items[i]),
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text('訊息', style: Theme.of(context).textTheme.displaySmall),
          const Spacer(),
          Material(
            color: AppColors.surfaceSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Haptics.light();
                // 想找誰聊就先去找物品 — 引導到首頁
                context.go('/');
                AppSnackbar.info(
                  context,
                  '從物品詳情頁的「聯絡」按鈕開始聊天吧',
                );
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.add_comment_outlined, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _tabs = ['全部', '未讀'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.allRound,
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                Haptics.select();
                onSelect(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.surface : Colors.transparent,
                  borderRadius: AppRadius.allRound,
                  boxShadow: sel ? AppShadows.xs : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[i],
                  style: TextStyle(
                    color:
                        sel ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.allMd,
      onTap: () {
        Haptics.light();
        context.push('/chat/${chat.id}', extra: {
          'name': chat.otherUserName,
          'avatar': chat.otherUserAvatar,
          'itemTitle': chat.itemTitle,
        });
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: chat.otherUserAvatar.isEmpty
                ? null
                : CachedNetworkImageProvider(chat.otherUserAvatar),
            backgroundColor: AppColors.surfaceSoft,
            child: chat.otherUserAvatar.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: AppColors.textTertiary)
                : null,
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
                        chat.otherUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      DateFormatter.relative(chat.lastMessageAt),
                      style: TextStyle(
                        color: chat.unreadCount > 0
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (chat.itemTitle.isNotEmpty)
                  Text(
                    chat.itemTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: chat.unreadCount > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (chat.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: AppRadius.allRound,
                        ),
                        child: Text(
                          '${chat.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
