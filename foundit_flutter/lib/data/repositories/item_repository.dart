import '../api/api_client.dart';
import '../mock/mock_items.dart';
import '../models/item.dart';
import '../models/item_stats.dart';

/// 物品查詢條件
class ItemFilter {
  final ItemType? type;
  final String? category;
  final String? area;
  final String? keyword;
  final bool? hasReward;
  final double? lat;
  final double? lng;
  final double? radius;
  final int page;
  final int pageSize;

  const ItemFilter({
    this.type,
    this.category,
    this.area,
    this.keyword,
    this.hasReward,
    this.lat,
    this.lng,
    this.radius,
    this.page = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toQuery() => {
        if (type != null) 'type': type!.code,
        if (category != null) 'category': category,
        if (area != null) 'area': area,
        if (keyword != null && keyword!.isNotEmpty) 'keyword': keyword,
        if (hasReward != null) 'has_reward': hasReward,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radius != null) 'radius': radius,
        'page': page,
        'page_size': pageSize,
      };

  ItemFilter copyWith({
    ItemType? type,
    Object? category = _sentinel,
    Object? keyword = _sentinel,
    int? page,
  }) {
    return ItemFilter(
      type: type ?? this.type,
      category: category == _sentinel ? this.category : category as String?,
      area: area,
      keyword: keyword == _sentinel ? this.keyword : keyword as String?,
      hasReward: hasReward,
      lat: lat,
      lng: lng,
      radius: radius,
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemFilter &&
          other.type == type &&
          other.category == category &&
          other.area == area &&
          other.keyword == keyword &&
          other.hasReward == hasReward &&
          other.lat == lat &&
          other.lng == lng &&
          other.radius == radius &&
          other.page == page &&
          other.pageSize == pageSize);

  @override
  int get hashCode => Object.hash(
        type, category, area, keyword, hasReward,
        lat, lng, radius, page, pageSize,
      );
}

abstract class ItemRepository {
  Future<List<Item>> list(ItemFilter filter);
  Future<Item?> detail(String id);
  Future<Item?> create(Item item);
  Future<bool> delete(String id);
  Future<bool> resolve(String id);

  /// 全平台統計（首頁榮譽帶 / 分類角標）
  Future<ItemStats> stats();
}

class MockItemRepository implements ItemRepository {
  final List<Item> _local = [...MockItems.items];

  @override
  Future<List<Item>> list(ItemFilter filter) async {
    await Future.delayed(const Duration(milliseconds: 350));
    var data = _local;
    if (filter.type != null) {
      data = data.where((i) => i.type == filter.type).toList();
    }
    if (filter.category != null && filter.category!.isNotEmpty) {
      data = data.where((i) => i.category == filter.category).toList();
    }
    if (filter.keyword != null && filter.keyword!.isNotEmpty) {
      final q = filter.keyword!;
      data = data
          .where((i) =>
              i.title.contains(q) ||
              i.description.contains(q) ||
              i.locationName.contains(q) ||
              i.category.contains(q))
          .toList();
    }
    if (filter.hasReward == true) {
      data = data.where((i) => i.hasReward).toList();
    }
    return data;
  }

  @override
  Future<Item?> detail(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _local.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Item?> create(Item item) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final created = Item(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      type: item.type,
      title: item.title,
      category: item.category,
      description: item.description,
      color: item.color,
      images: item.images,
      latitude: item.latitude,
      longitude: item.longitude,
      locationName: item.locationName,
      lostAt: item.lostAt,
      reward: item.reward,
      hasReward: item.hasReward,
      storageLocation: item.storageLocation,
      handedToPolice: item.handedToPolice,
      userName: 'David',
      userAvatar: 'https://i.pravatar.cc/150?img=5',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _local.insert(0, created);
    return created;
  }

  @override
  Future<bool> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _local.removeWhere((i) => i.id == id);
    return true;
  }

  @override
  Future<bool> resolve(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<ItemStats> stats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final byCat = <String, int>{};
    var active = 0, resolved = 0, lost = 0, found = 0;
    for (final i in _local) {
      if (i.status == ItemStatus.resolved) {
        resolved++;
        continue;
      }
      active++;
      if (i.type == ItemType.lost) lost++;
      if (i.type == ItemType.found) found++;
      byCat.update(i.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return ItemStats(
      totalActive: active,
      totalResolved: resolved,
      totalLost: lost,
      totalFound: found,
      byCategory: byCat,
    );
  }
}

class RemoteItemRepository implements ItemRepository {
  RemoteItemRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Item>> list(ItemFilter filter) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/items',
      query: filter.toQuery(),
    );
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Item?> detail(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/items/$id');
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? null : Item.fromJson(data);
  }

  @override
  Future<Item?> create(Item item) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/items',
      data: item.toCreateJson(),
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? null : Item.fromJson(data);
  }

  @override
  Future<bool> delete(String id) async {
    final res = await _api.delete<Map<String, dynamic>>('/items/$id');
    return res.data?['success'] as bool? ?? false;
  }

  @override
  Future<bool> resolve(String id) async {
    final res = await _api.patch<Map<String, dynamic>>('/items/$id/resolve');
    return res.data?['success'] as bool? ?? false;
  }

  @override
  Future<ItemStats> stats() async {
    final res = await _api.get<Map<String, dynamic>>('/items/stats');
    final data = res.data?['data'] as Map<String, dynamic>?;
    return data == null ? ItemStats.empty : ItemStats.fromJson(data);
  }
}
