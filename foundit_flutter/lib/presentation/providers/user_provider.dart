import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../widgets/foundit_ui.dart';
import 'core_providers.dart';

/// 「我的」頁的統計卡資料；refresh: ref.invalidate(userStatsProvider)
/// 後端負責 posted / helpful / found / lost；收藏數由本地 SharedPreferences 計算，
/// 因為「收藏」是行動端側的個人化資料，後端不需要儲存。
final userStatsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  final stats = await ref.watch(userRepositoryProvider).getStats();
  final prefs = ref.watch(sharedPreferencesProvider);
  final prefix = 'bookmark:${savedNamespace(prefs)}:';
  final bookmarks = prefs
      .getKeys()
      .where((k) => k.startsWith(prefix))
      .where((k) => prefs.getBool(k) == true)
      .length;
  return UserStats(
    posted: stats.posted,
    helpful: stats.helpful,
    bookmarks: bookmarks,
    foundCount: stats.foundCount,
    lostCount: stats.lostCount,
  );
});

/// 成就徽章列表
final userBadgesProvider = FutureProvider.autoDispose<List<BadgeInfo>>((ref) {
  return ref.watch(userRepositoryProvider).getBadges();
});
