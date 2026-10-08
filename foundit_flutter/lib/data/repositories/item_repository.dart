import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

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
        // 後端 keyword 上限 100 字。
        if (keyword != null && keyword!.trim().isNotEmpty)
          'keyword': keyword!.trim().length > 100
              ? keyword!.trim().substring(0, 100)
              : keyword!.trim(),
        if (hasReward != null) 'has_reward': hasReward,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radius != null) 'radius': radius,
        'page': page < 1 ? 1 : page,
        // 後端驗證 page_size 介於 1–50，超過會整個請求 400。
        'page_size': pageSize.clamp(1, maxPageSize),
      };

  static const maxPageSize = 50;

  ItemFilter copyWith({
    Object? type = _sentinel,
    Object? category = _sentinel,
    Object? area = _sentinel,
    Object? keyword = _sentinel,
    Object? hasReward = _sentinel,
    Object? lat = _sentinel,
    Object? lng = _sentinel,
    Object? radius = _sentinel,
    int? page,
    int? pageSize,
  }) {
    return ItemFilter(
      type: type == _sentinel ? this.type : type as ItemType?,
      category: category == _sentinel ? this.category : category as String?,
      area: area == _sentinel ? this.area : area as String?,
      keyword: keyword == _sentinel ? this.keyword : keyword as String?,
      hasReward: hasReward == _sentinel ? this.hasReward : hasReward as bool?,
      lat: lat == _sentinel ? this.lat : lat as double?,
      lng: lng == _sentinel ? this.lng : lng as double?,
      radius: radius == _sentinel ? this.radius : radius as double?,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
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
        type,
        category,
        area,
        keyword,
        hasReward,
        lat,
        lng,
        radius,
        page,
        pageSize,
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
  MockItemRepository({SharedPreferences? prefs}) : _prefs = prefs {
    _local = _readSavedItems() ?? [...MockItems.items];
  }

  /// Only demonstration data is stored here. Remote repositories never use it.
  static const _storageKey = 'foundit_demo_items_v1';
  final SharedPreferences? _prefs;
  late final List<Item> _local;

  List<Item>? _readSavedItems() {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null) return null;
    try {
      final rows = jsonDecode(raw) as List<dynamic>;
      return rows
          .map((row) => Item.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, dynamic> _toSavedJson(Item item) => {
        ...item.toCreateJson(),
        'id': item.id,
        'user_id': item.userId,
        'user_name': item.userName,
        'user_avatar': item.userAvatar,
        'user_verified': item.userVerified,
        'status': item.status.code,
        'created_at': item.createdAt.millisecondsSinceEpoch,
        'updated_at': item.updatedAt.millisecondsSinceEpoch,
      };

  Future<void> _persist() async {
    await _prefs?.setString(
      _storageKey,
      jsonEncode(_local.map(_toSavedJson).toList()),
    );
  }

  String _searchText(String value) =>
      value.trim().toLowerCase().replaceAll('臺', '台');

  double _distanceKm(Item item, double latitude, double longitude) {
    const toRadians = math.pi / 180;
    final latDelta = (item.latitude - latitude) * toRadians;
    final lngDelta = (item.longitude - longitude) * toRadians;
    final a = math.pow(math.sin(latDelta / 2), 2) +
        math.cos(latitude * toRadians) *
            math.cos(item.latitude * toRadians) *
            math.pow(math.sin(lngDelta / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  @override
  Future<List<Item>> list(ItemFilter filter) async {
    await Future.delayed(const Duration(milliseconds: 350));
    var data = _local.where((i) => i.status == ItemStatus.active).toList();
    if (filter.type != null) {
      data = data.where((i) => i.type == filter.type).toList();
    }
    if (filter.category != null && filter.category!.isNotEmpty) {
      data = data.where((i) => i.category == filter.category).toList();
    }
    final area = _searchText(filter.area ?? '');
    if (area.isNotEmpty && area != '全部地區') {
      data = data
          .where((i) => _searchText(i.locationName).contains(area))
          .toList();
    }
    final query = _searchText(filter.keyword ?? '');
    if (query.isNotEmpty) {
      final words = query.split(RegExp(r'\s+'));
      data = data.where((i) {
        final text = _searchText(
          '${i.title} ${i.description} ${i.locationName} ${i.category} ${i.color}',
        );
        return words.every(text.contains);
      }).toList();
    }
    if (filter.hasReward == true) {
      data = data.where((i) => i.hasReward).toList();
    }
    if (filter.lat != null && filter.lng != null && filter.radius != null) {
      data = data
          .where(
            (i) => _distanceKm(i, filter.lat!, filter.lng!) <= filter.radius!,
          )
          .toList();
    }
    data.sort((a, b) {
      final dateOrder = b.createdAt.compareTo(a.createdAt);
      return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
    });
    final pageSize = math.min(50, math.max(1, filter.pageSize));
    final offset = (math.max(1, filter.page) - 1) * pageSize;
    return List.unmodifiable(data.skip(offset).take(pageSize));
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
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      type: item.type,
      userId: 'me',
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
      userName: '我',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _local.insert(0, created);
    await _persist();
    return created;
  }

  @override
  Future<bool> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _local.indexWhere((i) => i.id == id);
    if (index == -1) return false;
    _local.removeAt(index);
    await _persist();
    return true;
  }

  @override
  Future<bool> resolve(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _local.indexWhere((i) => i.id == id);
    if (index == -1) return false;
    _local[index] = Item.fromJson({
      ..._toSavedJson(_local[index]),
      'status': ItemStatus.resolved.code,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _persist();
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
      if (i.status != ItemStatus.active) continue;
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
