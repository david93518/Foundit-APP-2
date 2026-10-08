import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/user_provider.dart';
import '../../widgets/foundit_ui.dart';

/// 「我的」：身分卡、三個數字、兩個捷徑，其餘收進設定。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDemo = ref.watch(useMockProvider);
    final isGuest = user == null;
    final name = isDemo
        ? '體驗訪客'
        : user == null
        ? '尚未登入'
        : user.name.isEmpty
        ? 'FOUND !T 使用者'
        : user.name;
    final narrow = MediaQuery.sizeOf(context).width < 650;
    final gutter = narrow ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (isDemo || isGuest) return;
            try {
              await ref.read(authProvider.notifier).refresh();
              ref.invalidate(userStatsProvider);
            } catch (_) {
              if (context.mounted) AppSnackbar.info(context, '暫時無法更新資料，請稍後再試。');
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '我的',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Panel(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _Avatar(
                                    url: isDemo ? '' : user?.avatarUrl ?? '',
                                    name: name,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -.3,
                                                ),
                                              ),
                                            ),
                                            if (!isDemo &&
                                                (user?.isVerified ??
                                                    false)) ...[
                                              const SizedBox(width: 5),
                                              const Icon(
                                                Icons.verified_rounded,
                                                size: 17,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isDemo
                                              ? '資料保存在此裝置'
                                              : isGuest
                                              ? '登入後，管理刊登與訊息'
                                              : '帳號已登入',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isDemo && !isGuest)
                                    IconButton(
                                      tooltip: '編輯個人資料',
                                      onPressed: () =>
                                          context.push('/profile/edit'),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.ink50,
                                        foregroundColor: AppColors.ink,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                      ),
                                    ),
                                ],
                              ),
                              if (!isDemo && isGuest) ...[
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: () => context.push('/login'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('登入 / 建立帳號'),
                                ),
                              ],
                              if (!isGuest) ...[
                                const SizedBox(height: 18),
                                _StatsRow(demo: isDemo),
                              ],
                              if (isDemo) ...[
                                const SizedBox(height: 14),
                                const Text(
                                  '目前為體驗模式，不需要提供手機或個人資料。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.inventory_2_outlined,
                              label: '我的刊登',
                              onTap: () => context.push('/my-items'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.bookmark_border_rounded,
                              label: '收藏的物品',
                              onTap: () => context.push('/saved'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _SectionTitle('物品管理'),
                      const SizedBox(height: 10),
                      _Panel(
                        child: _MenuRow(
                          icon: Icons.qr_code_rounded,
                          label: 'QR 防丟牌',
                          subtitle: '新增與管理物品的專屬 QR',
                          onTap: () => context.push('/qr'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionTitle('帳號與設定'),
                      const SizedBox(height: 10),
                      _Panel(
                        child: Column(
                          children: [
                            _MenuRow(
                              icon: Icons.settings_outlined,
                              label: '設定',
                              subtitle: '資料、搜尋紀錄與帳號',
                              onTap: () => context.push('/settings'),
                            ),
                            if (!isDemo && !isGuest) ...[
                              const Divider(height: 1, indent: 66),
                              _MenuRow(
                                icon: Icons.logout_rounded,
                                label: '登出帳號',
                                onTap: () async {
                                  await ref
                                      .read(authProvider.notifier)
                                      .logout();
                                  if (context.mounted) context.go('/profile');
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 刊登／協助歸還／收藏三個數字；載入中顯示骨架，失敗就安靜地不顯示。
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.demo});
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);
    Widget tile(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return stats.when(
      loading: () => Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            tile('刊登', '${s.posted}'),
            tile('協助歸還', '${s.helpful}'),
            tile('收藏', '${s.bookmarks}'),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String url;
  final String name;
  Widget _fallback() => ColoredBox(
    color: AppColors.ink50,
    child: Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: 58,
      height: 58,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: .2,
      ),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.ink50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.ink700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}
