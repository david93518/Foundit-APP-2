import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/foundit_ui.dart';

/// 訊息列表：每一列只放「誰、哪件物品、最後一句話」，未讀用陶土色點亮。
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _unreadOnly = false;

  Future<void> _refresh() async {
    Haptics.light();
    try {
      ref.invalidate(chatsProvider);
      await ref.read(chatsProvider.future);
    } catch (_) {
      if (mounted) AppSnackbar.info(context, '目前無法更新訊息，請稍後再試。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(useMockProvider);
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    final canViewChats = isDemo || isLoggedIn;
    final chats = canViewChats ? ref.watch(chatsProvider) : null;
    final narrow = MediaQuery.sizeOf(context).width < 650;
    final gutter = narrow ? 20.0 : 32.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '訊息',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDemo ? '示範對話 · 訊息不會傳送給真實使用者。' : '確認物品特徵，約定安心的領取方式。',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (canViewChats) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _FilterButton(
                            label: '全部對話',
                            selected: !_unreadOnly,
                            onTap: () => setState(() => _unreadOnly = false),
                          ),
                          const SizedBox(width: 8),
                          _FilterButton(
                            label: '未讀',
                            selected: _unreadOnly,
                            onTap: () => setState(() => _unreadOnly = true),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (!canViewChats)
                      EmptyPanel(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: '讓好消息找到你',
                        message: '登入後，就能與拾獲者或失主聯繫，在這裡追蹤每一則回覆。',
                        action: '登入帳號',
                        onAction: () => context.push('/login'),
                      )
                    else
                      chats!.when(
                        loading: () => const _ListSkeleton(),
                        error: (_, __) => EmptyPanel(
                          icon: Icons.wifi_off_rounded,
                          title: '訊息暫時載入不了',
                          message: '請確認網路連線，再試一次。你的對話會保留在這裡。',
                          action: '重新載入',
                          onAction: () => ref.invalidate(chatsProvider),
                        ),
                        data: (all) {
                          final items = _unreadOnly
                              ? all.where((c) => c.unreadCount > 0).toList()
                              : all;
                          if (items.isEmpty) {
                            return EmptyPanel(
                              icon: _unreadOnly
                                  ? Icons.mark_chat_read_outlined
                                  : Icons.forum_outlined,
                              title: _unreadOnly ? '訊息都讀完了' : '第一則對話，從物品開始',
                              message: _unreadOnly
                                  ? '有新的回覆時，會出現在這裡。'
                                  : '找到可能的物品後，從物品詳情頁聯繫對方。',
                              action: _unreadOnly ? '查看全部對話' : '去找找物品',
                              onAction: _unreadOnly
                                  ? () => setState(() => _unreadOnly = false)
                                  : () => context.go('/'),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++) ...[
                                      if (i > 0)
                                        const Divider(height: 1, indent: 78),
                                      _ChatRow(chat: items[i]),
                                    ],
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(6, 18, 6, 0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 15,
                                      color: AppColors.textTertiary,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '先核對物品特徵；請勿提供驗證碼或轉帳。',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.6,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.select();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.base),
        curve: AppMotion.curve,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    ),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unreadCount > 0;
    final displayName = chat.otherUserName.isEmpty
        ? '物品聯絡人'
        : chat.otherUserName;
    return InkWell(
      onTap: () {
        Haptics.light();
        context.push(
          '/chat/${chat.id}',
          extra: {
            'name': displayName,
            'avatar': chat.otherUserAvatar,
            'itemTitle': chat.itemTitle,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(name: displayName, url: chat.otherUserAvatar, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.relative(chat.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (chat.itemTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            chat.itemTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? '開始確認物品特徵'
                              : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 10),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

/// 對話頭像：有照片就顯示，沒有就用炭墨底的姓氏首字。
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    required this.url,
    this.size = 40,
  });
  final String name;
  final String url;
  final double size;

  Widget _fallback() => ColoredBox(
    color: AppColors.ink50,
    child: Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontSize: size * .4,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: url.isEmpty
          ? _fallback()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            ),
    ),
  );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.neutral100,
    highlightColor: AppColors.neutral50,
    period: const Duration(milliseconds: 1400),
    child: Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral100,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(.45, 14),
                      const SizedBox(height: 8),
                      _bar(.8, 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _bar(double fraction, double height) => FractionallySizedBox(
    widthFactor: fraction,
    alignment: Alignment.centerLeft,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
