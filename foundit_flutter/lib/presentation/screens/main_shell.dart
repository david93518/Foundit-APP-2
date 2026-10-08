import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../providers/core_providers.dart';
import '../widgets/foundit_ui.dart';

/// 主框架：手機為「首頁／地圖／刊登／訊息／我的」底部列，寬螢幕為左側欄。
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const destinations = [
    ('/home', '探索物品', Icons.home_outlined),
    ('/map', '地圖探索', Icons.map_outlined),
    ('/chats', '訊息', Icons.chat_bubble_outline_rounded),
    ('/saved', '收藏的物品', Icons.bookmark_border_rounded),
    ('/my-items', '我的刊登', Icons.inventory_2_outlined),
    ('/profile', '我的', Icons.person_outline_rounded),
  ];

  static void openPublishSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '刊登物品',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '選擇你想刊登的類型',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              for (final choice in [
                (
                  'lost',
                  '我遺失了物品',
                  '提供特徵，讓大家幫忙尋找',
                  Icons.search_rounded,
                  AppColors.ink,
                ),
                (
                  'found',
                  '我撿到了物品',
                  '登記拾獲資訊，讓失主找到你',
                  Icons.inventory_2_outlined,
                  AppColors.primary,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Pressable(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/add/${choice.$1}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: choice.$5,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              choice.$4,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  choice.$2,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  choice.$3,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final mock = ref.watch(useMockProvider);
    final title = destinations
        .firstWhere(
          (destination) => destination.$1 == location,
          orElse: () => destinations.first,
        )
        .$2;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (wide) _sidebar(context),
          Expanded(
            child: Column(
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: EdgeInsets.only(
                        left: wide ? 28 : 20,
                        right: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: wide
                                ? Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : const Align(
                                    alignment: Alignment.centerLeft,
                                    child: BrandMark(),
                                  ),
                          ),
                          if (mock &&
                              (wide ||
                                  MediaQuery.sizeOf(context).width >
                                      380 * scale))
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.ink50,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '體驗版',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: '通知',
                            onPressed: () => context.push('/notifications'),
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 23,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            tooltip: 'QR 防丟牌',
                            onPressed: () => context.push('/qr'),
                            icon: const Icon(
                              Icons.qr_code_rounded,
                              size: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            tooltip: '我的收藏',
                            onPressed: () => context.go('/saved'),
                            icon: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide || MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : _bottomBar(context),
    );
  }

  Widget _sidebar(BuildContext context) => Container(
    width: 196,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(right: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: BrandMark(),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => openPublishSheet(context),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('刊登物品'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (final destination in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton(
                onPressed: () => context.go(destination.$1),
                style: TextButton.styleFrom(
                  backgroundColor: location == destination.$1
                      ? AppColors.ink50
                      : Colors.transparent,
                  foregroundColor: location == destination.$1
                      ? AppColors.ink
                      : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(destination.$3, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: location == destination.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _bottomBar(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            _mobileNav(
              context,
              '/home',
              '首頁',
              Icons.home_outlined,
              Icons.home_rounded,
            ),
            _mobileNav(
              context,
              '/map',
              '地圖',
              Icons.map_outlined,
              Icons.map_rounded,
            ),
            Expanded(
              // Column(min) 而非 Center：Center 會在 Row 裡撐滿可用高度，
              // 把整個頁面內容擠掉。
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: '刊登物品',
                    child: Semantics(
                      button: true,
                      label: '刊登物品',
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        elevation: 0,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => openPublishSheet(context),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: .32,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _mobileNav(
              context,
              '/chats',
              '訊息',
              Icons.chat_bubble_outline_rounded,
              Icons.chat_bubble_rounded,
            ),
            _mobileNav(
              context,
              '/profile',
              '我的',
              Icons.person_outline_rounded,
              Icons.person_rounded,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mobileNav(
    BuildContext context,
    String path,
    String label,
    IconData icon,
    IconData selectedIcon,
  ) {
    final selected =
        location == path ||
        (path == '/profile' &&
            (location == '/my-items' || location == '/saved'));
    final color = selected ? AppColors.ink : AppColors.textTertiary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => context.go(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.base),
                  switchInCurve: AppMotion.curve,
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
