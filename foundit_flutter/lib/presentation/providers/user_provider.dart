import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../widgets/foundit_ui.dart';
import 'core_providers.dart';

/// 「我的」頁的統計卡資料；refresh: ref.invalidate(userStatsProvider)
/// 收藏與 Web 共用後端；此處訂閱記憶體快取，以便操作後立即更新統計。
final userStatsProvider = FutureProvider.autoDispose<UserStats>((ref) async {
  final bookmarks = ref.watch(savedItemsProvider).length;
  final stats = await ref.watch(userRepositoryProvider).getStats();
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
