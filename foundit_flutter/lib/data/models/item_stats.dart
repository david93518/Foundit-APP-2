/// 全平台物品統計 — 對應 backend `GET /items/stats`
class ItemStats {
  final int totalActive;
  final int totalResolved;
  final int totalLost;
  final int totalFound;

  /// 分類名稱 → 「目前還在尋找中」的件數
  final Map<String, int> byCategory;

  const ItemStats({
    this.totalActive = 0,
    this.totalResolved = 0,
    this.totalLost = 0,
    this.totalFound = 0,
    this.byCategory = const {},
  });

  static const empty = ItemStats();

  factory ItemStats.fromJson(Map<String, dynamic> json) {
    final raw = (json['by_category'] as Map?) ?? const {};
    final byCat = <String, int>{};
    raw.forEach((k, v) {
      if (k == null) return;
      byCat[k.toString()] = v is int ? v : int.tryParse(v.toString()) ?? 0;
    });
    return ItemStats(
      totalActive: (json['total_active'] as num?)?.toInt() ?? 0,
      totalResolved: (json['total_resolved'] as num?)?.toInt() ?? 0,
      totalLost: (json['total_lost'] as num?)?.toInt() ?? 0,
      totalFound: (json['total_found'] as num?)?.toInt() ?? 0,
      byCategory: byCat,
    );
  }
}
