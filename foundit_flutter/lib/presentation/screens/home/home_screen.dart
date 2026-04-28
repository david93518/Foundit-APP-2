import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/category_pill.dart';
import '../../widgets/item_card.dart';
import '../../widgets/skeleton_box.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategory = -1;

  Future<void> _onRefresh() async {
    Haptics.light();
    ref.invalidate(itemsProvider);
    ref.invalidate(itemStatsProvider);
    ref.invalidate(unreadCountAsyncProvider);
    ref.invalidate(notificationsProvider);
    await Future.wait([
      ref.read(currentItemsProvider.future),
      ref.read(itemStatsProvider.future),
      ref.read(unreadCountAsyncProvider.future),
    ]);
    if (!mounted) return;
    AppSnackbar.success(context, '已更新最新動態');
  }

  void _selectCategory(int i) {
    Haptics.select();
    final nextIndex = _selectedCategory == i ? -1 : i;
    setState(() => _selectedCategory = nextIndex);
    final category = nextIndex == -1
        ? null
        : AppConstants.itemCategories[nextIndex].name;
    ref.read(itemFilterProvider.notifier).update(
          (state) => state.copyWith(category: category),
        );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(currentItemsProvider);
    final statsAsync = ref.watch(itemStatsProvider);
    final unread = ref.watch(unreadCountProvider);
    final user = ref.watch(authProvider).user;
    final stats = statsAsync.value ?? ItemStats.empty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        strokeWidth: 2.4,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(
                userName: user?.name ?? '朋友',
                userAvatar: user?.avatarUrl ?? '',
                unreadCount: unread,
              ),
            ),
            SliverToBoxAdapter(
              child: _CommunityBanner(
                resolvedCount: stats.totalResolved,
                waitingCount: stats.totalActive,
                isLoading: statsAsync.isLoading && !statsAsync.hasValue,
              ),
            ),
            const SliverToBoxAdapter(child: _QuickActions()),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '你遺失了什麼？',
                subtitle: '點選分類快速尋找對應物品',
                action: '全部分類',
                onAction: () {
                  Haptics.light();
                  context.push('/search');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryRow(
                selectedIndex: _selectedCategory,
                onSelect: _selectCategory,
                counts: stats.byCategory,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '等待主人領回 🤝',
                subtitle: '失主正焦急等待，看你能不能幫上忙',
                action: '看更多',
                onAction: () {
                  Haptics.light();
                  context.push('/search');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: itemsAsync.when(
                  loading: () => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, __) =>
                        const ItemCardSkeleton(isList: false),
                  ),
                  error: (e, _) => _ErrorTile(onRetry: () {
                    ref.invalidate(itemsProvider);
                  }),
                  data: (items) {
                    final featured = items
                        .where((i) => i.status != ItemStatus.resolved)
                        .take(4)
                        .toList();
                    if (featured.isEmpty) {
                      return const _EmptyFeatured();
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: featured.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 14),
                      itemBuilder: (_, i) => FeaturedItemCard(
                        item: featured[i],
                        onTap: () {
                          Haptics.light();
                          context.push('/item/${featured[i].id}',
                              extra: featured[i]);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
            const SliverToBoxAdapter(
              child: _SectionHeader(
                title: '社群最新動態',
                subtitle: '看看大家正在如何互相幫助',
              ),
            ),
            itemsAsync.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const ItemCardSkeleton(),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorTile(onRetry: () {
                  ref.invalidate(itemsProvider);
                }),
              ),
              data: (items) {
                final recent = items.skip(2).toList();
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => AnimationConfiguration.staggeredList(
                      position: i,
                      duration: const Duration(milliseconds: 450),
                      child: SlideAnimation(
                        verticalOffset: 40,
                        child: FadeInAnimation(
                          child: ListItemCard(
                            item: recent[i],
                            onTap: () {
                              Haptics.light();
                              context.push('/item/${recent[i].id}',
                                  extra: recent[i]);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('載入失敗，請檢查網路連線',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _EmptyFeatured extends StatelessWidget {
  const _EmptyFeatured();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_emotions_outlined,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 12),
          const Text(
            '太棒了！目前沒有人有遺失物',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '撿到東西時，第一個來通報吧 ❤',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ───────── 任務導向：4 個快速捷徑 ─────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        'AI 配對',
        Icons.auto_awesome_rounded,
        AppColors.primaryGradient,
        '/ai-match',
      ),
      _QuickAction(
        'QR 防丟',
        Icons.qr_code_rounded,
        AppColors.mintGradient,
        '/qr',
      ),
      _QuickAction(
        '掃描認領',
        Icons.qr_code_scanner_rounded,
        AppColors.rewardGradient,
        '/qr/scan',
      ),
      _QuickAction(
        '附近物品',
        Icons.location_on_rounded,
        AppColors.sunsetGradient,
        '/map',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(
              child: _QuickActionTile(
                action: actions[i],
                onTap: () {
                  Haptics.light();
                  context.push(actions[i].route);
                },
              ),
            ),
            if (i != actions.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});
  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 58,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: action.gradient,
                borderRadius: AppRadius.allMd,
                boxShadow: AppShadows.sm,
              ),
              child: Icon(action.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final String route;
  const _QuickAction(this.label, this.icon, this.gradient, this.route);
}

// ───────── 頂部漸層 Hero 區（含問候 + 兩顆 CTA） ─────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.userName,
    required this.userAvatar,
    required this.unreadCount,
  });
  final String userName;
  final String userAvatar;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BottomCurveClipper(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 14,
          20,
          44,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    image: userAvatar.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(userAvatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: userAvatar.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 26,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Greeting.forNow(name: userName),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '今天想找回什麼？',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassIconButton(
                  icon: Icons.notifications_none_rounded,
                  badge: unreadCount > 0,
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SearchBar(),
            const SizedBox(height: AppSpacing.lg),
            const _HeroCtas(),
          ],
        ),
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 28);
    p.quadraticBezierTo(
      size.width / 2,
      size.height + 24,
      size.width,
      size.height - 28,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: AppRadius.allMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.allMd,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        if (badge)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.lost,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x66F97316), blurRadius: 6),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: () => context.push('/search'),
        borderRadius: AppRadius.allMd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (r) =>
                    AppColors.primaryGradient.createShader(r),
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '輸入物品名稱或地點，幫你找回家',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: AppRadius.allSm,
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.primary, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero 區的兩顆主要 CTA：我遺失了 / 我撿到了
class _HeroCtas extends StatelessWidget {
  const _HeroCtas();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroCtaTile(
            icon: Icons.search_rounded,
            label: '我遺失了',
            sub: '建立尋物啟事',
            gradient: const LinearGradient(
              colors: [Color(0xFFFB923C), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Haptics.light();
              context.push('/add/lost');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HeroCtaTile(
            icon: Icons.handshake_rounded,
            label: '我撿到了',
            sub: '通知失主領回',
            gradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Haptics.light();
              context.push('/add/found');
            },
          ),
        ),
      ],
    );
  }
}

class _HeroCtaTile extends StatelessWidget {
  const _HeroCtaTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.gradient,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppRadius.allMd,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
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
}

// ───────── 社群動態 banner ─────────

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner({
    required this.resolvedCount,
    required this.waitingCount,
    this.isLoading = false,
  });

  /// 已成功歸還
  final int resolvedCount;

  /// 還在等待主人領回
  final int waitingCount;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
        ),
        borderRadius: AppRadius.allLg,
        border: Border.all(color: const Color(0xFFFED7AA), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x22F59E0B),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🏆', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '社群已成功歸還 ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isLoading ? '—' : '$resolvedCount',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      ' 件',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isLoading
                      ? '正在和社群同步…'
                      : waitingCount > 0
                          ? '目前還有 $waitingCount 件等你出手相助'
                          : '感謝你的熱心 — 一起讓社群更有溫度',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── 分類區 ─────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedIndex,
    required this.onSelect,
    required this.counts,
  });
  final int selectedIndex;
  final Function(int) onSelect;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: AppConstants.itemCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final meta = AppConstants.itemCategories[i];
          return CategoryPill(
            meta: meta,
            selected: selectedIndex == i,
            count: counts[meta.name] ?? 0,
            onTap: () => onSelect(i),
          );
        },
      ),
    );
  }
}

// ───────── 區塊標題 ─────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Row(
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppColors.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
