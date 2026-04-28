import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// 個人頁
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isGuest = user == null;
    final name = (user?.name ?? '').isNotEmpty ? user!.name : '訪客';
    final phone = (user?.phone ?? '').isNotEmpty ? user!.phone : '尚未登入';
    final avatar = (user?.avatarUrl ?? '').isNotEmpty ? user!.avatarUrl : '';
    final points = user?.points ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(authProvider.notifier).refresh();
          ref.invalidate(userStatsProvider);
          await ref.read(userStatsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                name: name,
                phone: phone,
                avatar: avatar,
                points: points,
                isGuest: isGuest,
                onSettings: () => context.push('/settings'),
                onEdit: () => context.push('/profile/edit'),
                onLogin: () => context.go('/login'),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _StatsRow(),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _SectionTitle('功能與設定'),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _MenuCard(isGuest: isGuest),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '找得到 · v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────── Header ───────────

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.phone,
    required this.avatar,
    required this.points,
    required this.isGuest,
    required this.onSettings,
    required this.onEdit,
    required this.onLogin,
  });

  final String name;
  final String phone;
  final String avatar;
  final int points;
  final bool isGuest;
  final VoidCallback onSettings;
  final VoidCallback onEdit;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '我的',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.white24,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSettings,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.settings_outlined,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.allLg,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _Avatar(url: avatar),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: const BoxDecoration(
                          gradient: AppColors.rewardGradient,
                          borderRadius: AppRadius.allRound,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$points 積分',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _EditButton(
                  onTap: isGuest ? onLogin : onEdit,
                  label: isGuest ? '登入' : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: ClipOval(
        child: Container(
          color: AppColors.primary50,
          alignment: Alignment.center,
          child: url.isEmpty
              ? const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 30)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: 58,
                  height: 58,
                  placeholder: (_, __) => const Icon(Icons.person_rounded,
                      color: AppColors.primary200, size: 30),
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 30),
                ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap, this.label});
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary50,
      borderRadius: AppRadius.allRound,
      child: InkWell(
        borderRadius: AppRadius.allRound,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 10 : 12,
            vertical: 10,
          ),
          child: label != null
              ? Text(
                  label!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                )
              : const Icon(Icons.edit_rounded,
                  color: AppColors.primary, size: 18),
        ),
      ),
    );
  }
}

// ─────────── Section Title ───────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ─────────── Stats ───────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.md,
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 52,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, __) => Row(
          children: [
            Expanded(child: _stat('已登記', '—', AppColors.primary)),
            _divider(),
            Expanded(child: _stat('幫助次數', '—', AppColors.found)),
            _divider(),
            Expanded(child: _stat('收藏', '—', AppColors.reward)),
          ],
        ),
        data: (s) => Row(
          children: [
            Expanded(child: _stat('已登記', '${s.posted}', AppColors.primary)),
            _divider(),
            Expanded(child: _stat('幫助次數', '${s.helpful}', AppColors.found)),
            _divider(),
            Expanded(child: _stat('收藏', '${s.bookmarks}', AppColors.reward)),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.divider);

  Widget _stat(String label, String v, Color c) {
    return Column(
      children: [
        Text(
          v,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: c,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────── 選單 ───────────

class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.isGuest});
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.qr_code_rounded,
            color: AppColors.primary,
            label: 'QR 防丟標籤',
            subtitle: '為物品貼上專屬 QR',
            onTap: () => context.push('/qr'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.primary,
            label: 'AI 智慧配對',
            subtitle: '圖片辨識尋找相似物品',
            onTap: () => context.push('/ai-match'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: Icons.card_giftcard_rounded,
            color: AppColors.reward,
            label: '我的積分',
            subtitle: '達成任務換取獎勵',
            onTap: () =>
                AppSnackbar.info(context, '積分系統即將推出，敬請期待 ✨'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            color: AppColors.found,
            label: '通知',
            onTap: () => context.push('/notifications'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: Icons.shield_outlined,
            color: AppColors.primary,
            label: '隱私與安全',
            onTap: () => context.push('/settings'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            color: AppColors.primary,
            label: '幫助中心',
            onTap: () =>
                AppSnackbar.info(context, '說明中心即將推出，先試試各功能說明吧'),
          ),
          const _MenuDivider(),
          _MenuTile(
            icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
            color: AppColors.error,
            label: isGuest ? '登入 / 註冊' : '登出',
            destructive: !isGuest,
            onTap: () async {
              if (isGuest) {
                context.go('/login');
              } else {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = destructive ? AppColors.error : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.error50
                      : color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allSm,
                ),
                child: Icon(
                  icon,
                  color: destructive ? AppColors.error : color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!destructive)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Container(height: 1, color: AppColors.divider),
    );
  }
}
