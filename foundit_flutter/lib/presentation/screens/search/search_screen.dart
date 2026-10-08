import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/category_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/item_repository.dart';
import '../../providers/items_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/item_card.dart';
import '../../widgets/skeleton_box.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  ItemType? _filterType;
  String? _filterCategory;
  List<String> _recent = [];
  bool _searched = false;

  static const _hotTags = [
    '🎧 AirPods',
    '👛 錢包',
    '🔑 鑰匙',
    '💻 筆電',
    '🎒 背包',
    '📱 手機',
    '🐕 寵物',
    '👓 眼鏡',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(AppConstants.prefRecentSearches) ?? [];
    if (!mounted) return;
    setState(() => _recent = list);
  }

  Future<void> _pushRecent(String q) async {
    if (q.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = [q, ..._recent.where((e) => e != q)].take(10).toList();
    await prefs.setStringList(AppConstants.prefRecentSearches, list);
    if (!mounted) return;
    setState(() => _recent = list);
  }

  Future<void> _removeRecent(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recent.where((e) => e != q).toList();
    await prefs.setStringList(AppConstants.prefRecentSearches, list);
    if (!mounted) return;
    setState(() => _recent = list);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefRecentSearches);
    if (!mounted) return;
    setState(() => _recent = []);
  }

  void _performSearch(String q) {
    Haptics.light();
    _searchCtrl.text = q;
    _focus.unfocus();
    _pushRecent(q);
    setState(() => _searched = true);
  }

  ItemFilter get _filter => ItemFilter(
        keyword:
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        type: _filterType,
        category: _filterCategory,
        pageSize: 50,
      );

  bool get _showSuggestions =>
      !_searched && _searchCtrl.text.trim().isEmpty && _filterCategory == null;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchCtrl,
              focusNode: _focus,
              onBack: () => context.pop(),
              onChanged: (_) => setState(() {}),
              onSubmit: _performSearch,
            ),
            if (!_showSuggestions)
              _FilterRow(
                filterType: _filterType,
                filterCategory: _filterCategory,
                onTypeChange: (t) => setState(() => _filterType = t),
                onCategoryChange: (c) =>
                    setState(() => _filterCategory = c),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showSuggestions
                    ? _SuggestionsView(
                        key: const ValueKey('suggest'),
                        recent: _recent,
                        hotTags: _hotTags,
                        onTap: _performSearch,
                        onRemove: _removeRecent,
                        onClearAll: _clearRecent,
                      )
                    : _ResultsView(
                        key: const ValueKey('list'),
                        filter: _filter,
                        onClearFilters: () {
                          setState(() {
                            _filterType = null;
                            _filterCategory = null;
                            _searchCtrl.clear();
                            _searched = false;
                          });
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

class _ResultsView extends ConsumerWidget {
  const _ResultsView({
    super.key,
    required this.filter,
    required this.onClearFilters,
  });
  final ItemFilter filter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(itemsProvider(filter));
    return asyncList.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ItemCardSkeleton(),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text('搜尋失敗，請檢查網路連線',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(itemsProvider(filter)),
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: '找不到相符的物品',
            description: '試著調整篩選條件或換個關鍵字',
            ctaLabel: '清除篩選',
            onCta: onClearFilters,
          );
        }
        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 380),
              child: SlideAnimation(
                verticalOffset: 22,
                child: FadeInAnimation(
                  child: ListItemCard(
                    item: results[i],
                    onTap: () => context.push('/item/${results[i].id}',
                        extra: results[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: AppRadius.allMd,
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: onSubmit,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textTertiary),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        )
                      : null,
                  hintText: '搜尋物品、地點…',
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜尋建議畫面（輸入前）：最近搜尋 + 熱門標籤 + 大家在找什麼
class _SuggestionsView extends StatelessWidget {
  const _SuggestionsView({
    super.key,
    required this.recent,
    required this.hotTags,
    required this.onTap,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> recent;
  final List<String> hotTags;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        if (recent.isNotEmpty) ...[
          _SectionTitle(
            title: '最近搜尋',
            trailing: TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('清除全部',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
          const SizedBox(height: 4),
          ...recent.map((q) => _RecentTile(
                text: q,
                onTap: () => onTap(q),
                onRemove: () => onRemove(q),
              )),
          const SizedBox(height: 20),
        ],
        const _SectionTitle(title: '熱門搜尋'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hotTags.asMap().entries.map((e) {
            final rankColor = e.key < 3 ? AppColors.lost : AppColors.primary;
            return _HotChip(
              label: e.value,
              rank: e.key + 1,
              rankColor: rankColor,
              onTap: () => onTap(e.value.split(' ').last),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: '熱門分類'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: AppConstants.itemCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (_, i) {
            final c = AppConstants.itemCategories[i];
            return _CategoryTile(
              icon: categoryIcon(c.name),
              label: c.name,
              onTap: () => onTap(c.name),
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppColors.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textTertiary),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onRemove,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.north_west_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotChip extends StatelessWidget {
  const _HotChip({
    required this.label,
    required this.rank,
    required this.rankColor,
    required this.onTap,
  });

  final String label;
  final int rank;
  final Color rankColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allRound,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allRound,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allRound,
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: AppRadius.allXs,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.allMd,
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.ink50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filterType,
    required this.filterCategory,
    required this.onTypeChange,
    required this.onCategoryChange,
  });

  final ItemType? filterType;
  final String? filterCategory;
  final ValueChanged<ItemType?> onTypeChange;
  final ValueChanged<String?> onCategoryChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Chip(
            label: '全部',
            selected: filterType == null,
            onTap: () => onTypeChange(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '遺失物',
            selected: filterType == ItemType.lost,
            color: AppColors.lost,
            onTap: () => onTypeChange(
                filterType == ItemType.lost ? null : ItemType.lost),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '撿到物',
            selected: filterType == ItemType.found,
            color: AppColors.found,
            onTap: () => onTypeChange(
                filterType == ItemType.found ? null : ItemType.found),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: AppColors.divider),
          const SizedBox(width: 16),
          ...AppConstants.itemCategories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: '${c.emoji} ${c.name}',
                  selected: filterCategory == c.name,
                  onTap: () => onCategoryChange(
                      filterCategory == c.name ? null : c.name),
                ),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: selected ? c : AppColors.surfaceSoft,
      borderRadius: AppRadius.allRound,
      child: InkWell(
        onTap: () {
          Haptics.select();
          onTap();
        },
        borderRadius: AppRadius.allRound,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
