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

/// 便捷：目前篩選結果
final currentItemsProvider = FutureProvider.autoDispose<List<Item>>((ref) {
  final filter = ref.watch(itemFilterProvider);
  return ref.watch(itemsProvider(filter).future);
});

/// 「精選」物品（前 5 筆有懸賞的）
final featuredItemsProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final list = await ref.watch(
      itemsProvider(const ItemFilter(hasReward: true, pageSize: 5)).future);
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
