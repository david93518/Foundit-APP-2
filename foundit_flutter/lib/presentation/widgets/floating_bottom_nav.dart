import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

const kNavItems = [
  NavItem(Icons.home_outlined, Icons.home_rounded, '首頁'),
  NavItem(Icons.explore_outlined, Icons.explore_rounded, '探索'),
  NavItem(Icons.add_rounded, Icons.add_rounded, '新增'),
  NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '訊息'),
  NavItem(Icons.person_outline_rounded, Icons.person_rounded, '我的'),
];

/// 浮動式圓角底部導航，中央的「新增」是漸層凸起按鈕
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.allRound,
            boxShadow: AppShadows.lg,
          ),
          child: Row(
            children: List.generate(kNavItems.length, (i) {
              if (i == 2) {
                return _CenterFab(
                  onTap: () => onTap(i),
                  selected: currentIndex == i,
                );
              }
              return Expanded(
                child: _NavTile(
                  item: kNavItems[i],
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.allRound,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (c, a) =>
                  ScaleTransition(scale: a, child: c),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                size: 24,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.onTap, required this.selected});
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -14),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Ink(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.primary,
                  border: Border.all(color: AppColors.surface, width: 4),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
