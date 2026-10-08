import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

import '../../widgets/foundit_ui.dart';

final collectionProvider = FutureProvider.autoDispose.family<List<Item>, bool>((
  ref,
  saved,
) async {
  final repo = ref.watch(itemRepositoryProvider);
  if (saved) {
    final ids = ref.watch(savedItemsProvider);
    final items = await Future.wait(
      ids.map((id) async {
        try {
          return await repo.detail(id);
        } on DioException catch (error) {
          // 已刪除或格式錯誤的 id 只略過那一筆；連線問題才讓整頁顯示重試。
          if (error.response != null) return null;
          rethrow;
        }
      }),
    );
    return items.whereType<Item>().toList();
  }
  final mock = ref.watch(useMockProvider);
  if (mock) {
    // Include resolved posts; public listings intentionally show active items only.
    final prefs = ref.watch(sharedPreferencesProvider);
    final ids = prefs.getStringList('foundit_my_item_ids') ?? [];
    final items = await Future.wait(
      ids.map((id) async {
        try {
          return await repo.detail(id);
        } on DioException catch (error) {
          // 已刪除或格式錯誤的 id 只略過那一筆；連線問題才讓整頁顯示重試。
          if (error.response != null) return null;
          rethrow;
        }
      }),
    );
    return items
        .whereType<Item>()
        .where((i) => i.userId == 'me')
        .toList()
        .reversed
        .toList();
  }
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final res = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/users/me/items');
  final data = res.data?['data'];
  return (data is List ? data : <dynamic>[])
      .map((j) => Item.fromJson(j as Map<String, dynamic>))
      .toList();
});

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, this.saved = false});
  final bool saved;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Refresh after returning from a detail page or creating a post.
    final items = ref.watch(collectionProvider(saved));
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 650 ? 20 : 36,
              24,
              MediaQuery.sizeOf(context).width < 650 ? 20 : 36,
              104,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved ? '我的收藏' : '我的刊登',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  saved ? '收藏可能的物品，隨時回來核對。' : '管理你刊登的遺失物與拾獲物。',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                items.when(
                  loading: () => const ItemGridSkeleton(columns: 1, rows: 3),
                  error: (_, __) => EmptyPanel(
                    title: '目前無法載入',
                    message: '請稍後再試一次。',
                    action: '重試',
                    onAction: () => ref.invalidate(collectionProvider(saved)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return EmptyPanel(
                        icon: saved
                            ? Icons.bookmark_border_rounded
                            : Icons.inventory_2_outlined,
                        title: saved ? '還沒有收藏的物品' : '從你的第一則刊登開始',
                        message: saved
                            ? '看到可能的物品，點一下書籤就能收藏。'
                            : '不論是遺失或拾獲，我們都陪你找到下一步。',
                        action: saved ? '探索物品' : '刊登協尋',
                        onAction: () => saved
                            ? context.go('/home')
                            : context.push('/add/lost'),
                      );
                    }
                    return LayoutBuilder(
                      builder: (_, c) {
                        final cols = c.maxWidth >= 760 ? 2 : 1;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: list
                              .map(
                                (i) => SizedBox(
                                  width: (c.maxWidth - 16 * (cols - 1)) / cols,
                                  child: FoundItemCard(
                                    item: i,
                                    horizontal: true,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
