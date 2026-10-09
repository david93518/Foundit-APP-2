import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/safety_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.watch(apiClientProvider));
});

final blockedContactsProvider =
    FutureProvider.autoDispose<List<BlockedContact>>((ref) {
      ref.watch(authProvider.select((state) => state.user?.id));
      if (ref.watch(useMockProvider)) return [];
      return ref.watch(safetyRepositoryProvider).blockedContacts();
    });
