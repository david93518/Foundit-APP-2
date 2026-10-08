import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/item.dart';
import '../../data/models/item_stats.dart';
import '../../data/repositories/item_repository.dart';
import 'core_providers.dart';

/// 當前首頁的過濾條件
final itemFilterProvider = StateProvider<ItemFilter>((ref) {
  return const ItemFilter();
});

/// 首頁 / 搜尋用的物品清單（async family 依賴 filter）
final itemsProvider =
    FutureProvider.autoDispose.family<List<Item>, ItemFilter>((ref, filter) {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.list(filter);
});

/// A home feed assembled from the existing page cache, so item invalidation
/// after publishing/resolving also refreshes every displayed page.
class HomeItemPages {
  const HomeItemPages({
    required this.items,
    required this.loadedPages,
    required this.hasMore,
    this.loading = false,
    this.error,
  });
  static const pageSize = 20;
  final List<Item> items;
  final int loadedPages;
  final bool hasMore;
  final bool loading;
  final Object? error;
}

final homeItemPagesProvider = Provider.autoDispose
    .family<HomeItemPages, ({ItemFilter filter, int pages})>((ref, request) {
  final merged = <String, Item>{};
  for (var number = 1; number <= request.pages; number++) {
    final page = ref.watch(
      itemsProvider(
        request.filter.copyWith(
          page: number,
          pageSize: HomeItemPages.pageSize,
        ),
      ),
    );
    if (page.isLoading || page.hasError) {
      return HomeItemPages(
        items: List.unmodifiable(merged.values),
        loadedPages: number - 1,
        hasMore: true,
        loading: page.isLoading,
        error: page.hasError ? page.error : null,
      );
    }
    final rows = page.requireValue;
    for (final item in rows) {
      merged[item.id] = item;
    }
    if (rows.length < HomeItemPages.pageSize) {
      return HomeItemPages(
        items: List.unmodifiable(merged.values),
        loadedPages: number,
        hasMore: false,
      );
    }
  }
  return HomeItemPages(
    items: List.unmodifiable(merged.values),
    loadedPages: request.pages,
    hasMore: true,
  );
});

/// 地圖用：後端單頁上限 50 筆，所以逐頁抓到底（最多 [mapMaxPages] 頁）。
const mapPageSize = 50;
const mapMaxPages = 6;
final mapItemsProvider =
    FutureProvider.autoDispose.family<List<Item>, ItemType?>((ref, type) async {
  final repo = ref.watch(itemRepositoryProvider);
  final merged = <String, Item>{};
  for (var page = 1; page <= mapMaxPages; page++) {
    final rows = await repo.list(
      ItemFilter(type: type, page: page, pageSize: mapPageSize),
    );
    for (final item in rows) {
      merged[item.id] = item;
    }
    if (rows.length < mapPageSize) break;
  }
  return List.unmodifiable(merged.values);
});

/// 便捷：目前篩選結果
final currentItemsProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  final filter = ref.watch(itemFilterProvider);
  return ref.watch(itemsProvider(filter).future);
});

/// 「精選」物品（前 5 筆有懸賞的）
final featuredItemsProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final list = await ref.watch(
    itemsProvider(const ItemFilter(hasReward: true, pageSize: 5)).future,
  );
  return list.take(5).toList();
});

/// 首頁榮譽帶 / 分類角標用 — 全平台統計
final itemStatsProvider = FutureProvider.autoDispose<ItemStats>((ref) {
  return ref.watch(itemRepositoryProvider).stats();
});

/// 單一物品詳情
final itemDetailProvider =
    FutureProvider.autoDispose.family<Item?, String>((ref, id) {
  return ref.watch(itemRepositoryProvider).detail(id);
});

/// 建立物品（使用 StateNotifier 回傳狀態）
class CreateItemNotifier extends StateNotifier<AsyncValue<Item?>> {
  CreateItemNotifier(this._repo) : super(const AsyncValue.data(null));
  final ItemRepository _repo;

  Future<Item?> submit(Item draft) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repo.create(draft);
      state = AsyncValue.data(created);
      return created;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final createItemProvider =
    StateNotifierProvider<CreateItemNotifier, AsyncValue<Item?>>((ref) {
  return CreateItemNotifier(ref.watch(itemRepositoryProvider));
});
