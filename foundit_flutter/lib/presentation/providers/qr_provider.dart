import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/qr_item.dart';
import 'core_providers.dart';

/// 我的 QR 防丟貼紙列表
final myQrItemsProvider = FutureProvider.autoDispose<List<QrItemModel>>((ref) {
  return ref.watch(qrRepositoryProvider).listMine();
});
