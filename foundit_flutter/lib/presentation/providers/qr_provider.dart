import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/qr_item.dart';
import 'core_providers.dart';

/// 我的 QR 防丟貼紙列表
final myQrItemsProvider =
    AsyncNotifierProvider.autoDispose<MyQrItemsNotifier, List<QrItemModel>>(
      MyQrItemsNotifier.new,
    );

class MyQrItemsNotifier extends AutoDisposeAsyncNotifier<List<QrItemModel>> {
  @override
  Future<List<QrItemModel>> build() =>
      ref.watch(qrRepositoryProvider).listMine();

  /// 移除成功後立刻從清單拿掉，不必等重新載入。
  void drop(String id) {
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData([
      for (final item in items)
        if (item.id != id) item,
    ]);
  }

  /// 編輯成功後以伺服器回傳的版本取代；清單尚未載入時回傳 false。
  bool replace(QrItemModel updated) {
    final items = state.valueOrNull;
    if (items == null || !items.any((item) => item.id == updated.id)) {
      return false;
    }
    state = AsyncData([
      for (final item in items) item.id == updated.id ? updated : item,
    ]);
    return true;
  }
}
