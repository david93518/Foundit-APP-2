import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/category_icons.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/item_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/items_provider.dart';
import '../../widgets/foundit_ui.dart';

/// 首頁：先問使用者「你是弄丟了，還是撿到了」，再讓物品自己說話。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// null = 全部；預設顯示所有物品，避免只看單一類型時誤以為沒資料。
  ItemType? _type;
  String? _category;
  String? _area;
  String _query = '';
  bool _recent = false;
  int _pages = 1;

  static const _categories = [
    ('全部', null),
    ('包包', '包包/背包'),
    ('錢包', '錢包/皮夾'),
    ('電子產品', '電子產品'),
    ('鑰匙', '鑰匙'),
    ('證件', '文件/證件'),
    ('其他', '其他'),
  ];

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _category = null;
      _area = null;
      _recent = false;
      _pages = 1;
    });
  }

  void _searchNow() {
    _debounce?.cancel();
    setState(() {
      _query = _search.text.trim();
      _pages = 1;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '搜尋時間',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              for (final recent in [false, true])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(recent ? '最近 7 天' : '不限時間'),
                  trailing: Icon(
                    _recent == recent
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.primary,
                  ),
                  onTap: () => Navigator.pop(c, recent),
                ),
              const SizedBox(height: 8),
              const Text(
                '依物品遺失或拾獲日期篩選。',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _recent = result;
        _pages = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ItemFilter(
      type: _type,
      category: _category,
      area: _area,
      keyword: _query,
      pageSize: HomeItemPages.pageSize,
    );
    final feed = ref.watch(
      homeItemPagesProvider((filter: filter, pages: _pages)),
    );
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final narrow = width < 650;
    final gutter = narrow ? 20.0 : 36.0;
    // 內容最寬 1140，置中；超出的寬度平均留白。
    final side = ((width - 1140) / 2).clamp(0.0, double.infinity) + gutter;
    final columns = width < 420 && textScale > 1.5
        ? 1
        : narrow
        ? 2
        : width < 1000
        ? 3
        : 4;
    final hasFilter =
        _query.isNotEmpty || _category != null || _area != null || _recent;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() => _pages = 1);
          ref.invalidate(itemsProvider);
          try {
            await ref.read(itemsProvider(filter).future);
          } catch (_) {
            // The feed renders the provider's retry state after an offline refresh.
          }
        },
        child: AnimationLimiter(
          // 一次建立整頁（非惰性），列表最多幾十張卡，換來捲動時零跳動。
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, narrow ? 18 : 30, side, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(textScale),
                SizedBox(height: narrow ? 16 : 22),
                _intentRow(),
                const SizedBox(height: 16),
                _searchRow(),
                const SizedBox(height: 14),
                _typeSwitch(),
                const SizedBox(height: 12),
                _categoryRow(textScale),
                const SizedBox(height: 18),
                if (hasFilter) _filterSummary(),
                SectionHeader(
                  switch (_type) {
                    ItemType.found => '等主人帶回家的物品',
                    ItemType.lost => '一起幫忙留意',
                    null => '大家最近刊登的物品',
                  },
                  trailing: const Text(
                    '最新刊登',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _results(feed, filter, hasFilter, columns, reduceMotion),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: _qrBanner()),
                if (ref.watch(useMockProvider))
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      '體驗模式 · 此處物品皆為示範資料',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(double textScale) => LayoutBuilder(
    builder: (_, c) {
      const heading = Text(
        '探索失物',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          height: 1.2,
        ),
      );
      final stacked = c.maxWidth < 300 * textScale;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stacked) ...[
            heading,
            const SizedBox(height: 8),
            _areaPicker(),
          ] else
            Row(
              children: [
                const Expanded(child: heading),
                _areaPicker(),
              ],
            ),
          const SizedBox(height: 4),
          const Text(
            '正在找的，也許就在這裡。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    },
  );

  /// 兩個最重要的入口：先決定「我是哪一邊」，其餘才是瀏覽。
  Widget _intentRow() => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _IntentCard(
            label: '我弄丟了東西',
            hint: '讓附近的人幫你留意',
            icon: Icons.search_rounded,
            color: AppColors.ink,
            onColor: AppColors.onInk,
            onTap: () => context.push('/add/lost'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IntentCard(
            label: '我撿到了東西',
            hint: '讓失主可以找到你',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
            onColor: AppColors.onPrimary,
            onTap: () => context.push('/add/found'),
          ),
        ),
      ],
    ),
  );

  Widget _searchRow() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _search,
          onChanged: (s) {
            setState(() {});
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              setState(() {
                _query = s.trim();
                _pages = 1;
              });
            });
          },
          onSubmitted: (_) => _searchNow(),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: '搜尋物品、品牌或地點',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
            ),
            suffixIcon: _search.text.isNotEmpty
                ? IconButton(
                    tooltip: '清除關鍵字',
                    onPressed: () {
                      _debounce?.cancel();
                      _search.clear();
                      setState(() {
                        _query = '';
                        _pages = 1;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  )
                : null,
          ),
        ),
      ),
      const SizedBox(width: 10),
      IconButton(
        tooltip: _recent ? '最近 7 天' : '篩選',
        onPressed: _filters,
        style: IconButton.styleFrom(
          backgroundColor: _recent ? AppColors.ink : AppColors.surface,
          foregroundColor: _recent ? AppColors.onInk : AppColors.textPrimary,
          minimumSize: const Size(50, 50),
          side: BorderSide(color: _recent ? AppColors.ink : AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.tune_rounded, size: 21),
      ),
    ],
  );

  Widget _typeSwitch() => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        _typeTab('全部', null),
        _typeTab('撿到的', ItemType.found),
        _typeTab('在找的', ItemType.lost),
      ],
    ),
  );

  Widget _typeTab(String label, ItemType? type) {
    final selected = type == _type;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _type = type;
            _pages = 1;
          }),
          // 外層 48px 是觸控範圍，內層 40px 是視覺。
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.curve,
            constraints: const BoxConstraints(minHeight: 40),
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x14282B30),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.ink : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryRow(double textScale) => SizedBox(
    height: 48 * (textScale > 1.3 ? textScale * .8 : 1),
    child: ListView(
      key: const ValueKey('home-categories'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      children: [
        for (final (label, category) in _categories)
          Padding(
            key: ValueKey('category-$label'),
            padding: const EdgeInsets.only(right: 8),
            child: _categoryChip(label, category),
          ),
      ],
    ),
  );

  Widget _categoryChip(String label, String? category) {
    final selected = _category == category;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _category = category;
          _pages = 1;
        }),
        // 膠囊 40px 高，上下各留 4px 讓觸控範圍達到 48px。
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.base),
          curve: AppMotion.curve,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                categoryIcon(category),
                size: 16,
                color: selected ? AppColors.onInk : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.onInk : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterSummary() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            [
              if (_query.isNotEmpty) '「$_query」',
              if (_category != null) _category!,
              if (_area != null) _area!,
              if (_recent) '最近 7 天',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: _clear, child: const Text('清除篩選')),
      ],
    ),
  );

  Widget _results(
    HomeItemPages feed,
    ItemFilter filter,
    bool hasFilter,
    int columns,
    bool reduceMotion,
  ) {
    void retry() => ref.invalidate(
      itemsProvider(filter.copyWith(page: feed.loadedPages + 1)),
    );
    if (feed.items.isEmpty && feed.loading) {
      return ItemGridSkeleton(columns: columns);
    }
    if (feed.items.isEmpty && feed.error != null) {
      return EmptyPanel(
        title: '目前無法載入物品',
        message: '請檢查網路連線後再試一次。',
        action: '重新載入',
        onAction: retry,
        icon: Icons.cloud_off_outlined,
      );
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final list = feed.items
        .where(
          (item) =>
              item.status == ItemStatus.active &&
              (!_recent || item.lostAt.isAfter(cutoff)),
        )
        .toList();
    if (list.isEmpty && !hasFilter && _type != null) {
      return EmptyPanel(
        title: _type == ItemType.found ? '目前沒有待認領的物品' : '目前沒有協尋中的物品',
        message: '切到「全部」看看其他刊登，或按下方「＋」新增一筆。',
        action: '查看全部',
        onAction: () => setState(() {
          _type = null;
          _pages = 1;
        }),
      );
    }
    if (list.isEmpty && !hasFilter) {
      return const EmptyPanel(
        title: '目前還沒有刊登的物品',
        message: '成為第一個刊登的人，按下方「＋」讓附近的人幫你留意。',
      );
    }
    if (list.isEmpty) {
      return EmptyPanel(
        title: feed.hasMore ? '已載入的物品尚無符合結果' : '還沒有符合的物品',
        message: feed.hasMore ? '可以繼續載入物品，或調整篩選條件。' : '試試其他關鍵字，或刊登協尋，讓更多人幫你留意。',
        action: '清除篩選',
        onAction: _clear,
      );
    }
    final rows = <Widget>[];
    for (var start = 0; start < list.length; start += columns) {
      final slice = list.sublist(
        start,
        start + columns > list.length ? list.length : start + columns,
      );
      Widget row = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < columns - 1 ? 12 : 0),
                    child: i < slice.length
                        ? FoundItemCard(item: slice[i])
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      );
      if (!reduceMotion) {
        row = AnimationConfiguration.staggeredList(
          position: start ~/ columns,
          duration: AppMotion.slow,
          child: SlideAnimation(
            verticalOffset: 28,
            curve: AppMotion.curve,
            child: FadeInAnimation(child: row),
          ),
        );
      }
      rows.add(row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        Text(
          '已顯示 ${list.length} 件',
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        if (feed.hasMore || feed.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Center(
              child: Column(
                children: [
                  if (feed.error != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '後續物品暫時載入不了，已顯示的物品仍可查看。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: feed.loading
                        ? null
                        : feed.error != null
                        ? retry
                        : () => setState(() => _pages = feed.loadedPages + 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(160, 46),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: feed.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(
                      feed.loading
                          ? '載入中…'
                          : feed.error != null
                          ? '重新載入'
                          : '載入更多',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _areaPicker() => Container(
    padding: const EdgeInsets.only(left: 10, right: 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.divider),
    ),
    // 48px 高的觸控範圍；DropdownButton 預設只有文字高度。
    child: SizedBox(
      height: 48,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _area ?? '全部地區',
          itemHeight: null,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontFamily: 'NotoSansTC',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          selectedItemBuilder: (_) => [
            for (final a in AppConstants.areas)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(a),
                ],
              ),
          ],
          items: AppConstants.areas
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(a),
                  ),
                ),
              )
              .toList(),
          onChanged: (s) => setState(() {
            _area = s == '全部地區' ? null : s;
            _pages = 1;
          }),
        ),
      ),
    ),
  );

  Widget _qrBanner() => Pressable(
    onTap: () => context.push('/qr'),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          BracketMark(
            size: 46,
            color: AppColors.onInk.withValues(alpha: .5),
            strokeWidth: 2.4,
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 24,
              color: AppColors.onInk,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '給重要物品，一張防丟貼',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onInk,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '掃描 QR，讓拾獲者聯絡你',
                  style: TextStyle(fontSize: 12, color: AppColors.onInkMuted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.onInk,
          ),
        ],
      ),
    ),
  );
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.onTap,
  });
  final String label, hint;
  final IconData icon;
  final Color color;

  /// 放在 [color] 上的文字與圖示：炭墨用 onInk、陶土用 onPrimary。
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: '$label，$hint',
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: onColor.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: onColor, size: 19),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: onColor,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: onColor.withValues(alpha: .78),
            ),
          ),
        ],
      ),
    ),
  );
}
