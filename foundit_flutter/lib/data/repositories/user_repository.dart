import '../api/api_client.dart';
import '../models/user.dart';

/// 「我的」頁的延伸資料（統計 / 徽章）。
/// AuthRepository 負責 user 本身；這裡只專注 derived data。
abstract class UserRepository {
  Future<UserStats> getStats();
  Future<List<BadgeInfo>> getBadges();
}

class MockUserRepository implements UserRepository {
  @override
  Future<UserStats> getStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const UserStats(posted: 8, helpful: 3, bookmarks: 0,
        foundCount: 4, lostCount: 4);
  }

  @override
  Future<List<BadgeInfo>> getBadges() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      BadgeInfo(
        code: 'helpful_citizen',
        name: '熱心公民',
        emoji: '🎖️',
        unlocked: true,
        progress: 1,
        description: '完成第一次成功幫助',
      ),
      BadgeInfo(
        code: 'streak_30',
        name: '連續 30 天',
        emoji: '🔥',
        unlocked: false,
        progress: 0.4,
        description: '帳號使用滿 30 天',
      ),
    ];
  }
}

class RemoteUserRepository implements UserRepository {
  RemoteUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<UserStats> getStats() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/users/me/stats');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return const UserStats();
      return UserStats.fromJson(data);
    } catch (_) {
      return const UserStats();
    }
  }

  @override
  Future<List<BadgeInfo>> getBadges() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/users/me/badges');
      final list = res.data?['data'] as List<dynamic>?;
      if (list == null) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(BadgeInfo.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
