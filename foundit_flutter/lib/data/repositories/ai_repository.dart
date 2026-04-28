import '../api/api_client.dart';
import '../models/item.dart';

class AiMatchResult {
  final Item item;
  final double score;
  final int similarityPercent;

  const AiMatchResult({
    required this.item,
    required this.score,
    required this.similarityPercent,
  });

  factory AiMatchResult.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] as Map<String, dynamic>?;
    return AiMatchResult(
      item: Item.fromJson(itemJson ?? const {}),
      score: ((json['score'] as num?) ?? 0).toDouble(),
      similarityPercent: ((json['similarity_percent'] ??
              json['similarityPercent']) as num?)
          ?.toInt() ??
          0,
    );
  }
}

abstract class AiRepository {
  /// 以「關鍵字」、「我的物品 id」、或「圖片 URL」做配對
  Future<List<AiMatchResult>> match({
    String? keyword,
    String? itemId,
    String? imageUrl,
  });
}

class RemoteAiRepository implements AiRepository {
  RemoteAiRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<AiMatchResult>> match({
    String? keyword,
    String? itemId,
    String? imageUrl,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/ai/match',
      data: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (itemId != null && itemId.isNotEmpty) 'item_id': itemId,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
    );
    final raw = res.data?['data'] as List? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AiMatchResult.fromJson)
        .toList();
  }
}

class MockAiRepository implements AiRepository {
  @override
  Future<List<AiMatchResult>> match({
    String? keyword,
    String? itemId,
    String? imageUrl,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return const [];
  }
}
