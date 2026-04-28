import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/qr_repository.dart';
import '../../data/repositories/upload_repository.dart';
import '../../data/repositories/user_repository.dart';

/// SharedPreferences — 入口由 `main.dart` 在 bootstrap 期間用 overrideWithValue 提供
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'Override sharedPreferencesProvider in ProviderScope'),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiClient(prefs);
});

/// 是否使用 Mock；在 UI 開發階段讀 `AppConstants.useMock`，也可在測試時 override
final useMockProvider = Provider<bool>((_) => AppConstants.useMock);

// ── Repositories ──

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (ref.watch(useMockProvider)) {
    return MockAuthRepository(prefs);
  }
  return RemoteAuthRepository(ref.watch(apiClientProvider), prefs);
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockItemRepository();
  return RemoteItemRepository(ref.watch(apiClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockChatRepository();
  return RemoteChatRepository(ref.watch(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockNotificationRepository();
  return RemoteNotificationRepository(ref.watch(apiClientProvider));
});

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockUploadRepository();
  return RemoteUploadRepository(ref.watch(apiClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockUserRepository();
  return RemoteUserRepository(ref.watch(apiClientProvider));
});

final qrRepositoryProvider = Provider<QrRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockQrRepository();
  return RemoteQrRepository(ref.watch(apiClientProvider));
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  if (ref.watch(useMockProvider)) return MockAiRepository();
  return RemoteAiRepository(ref.watch(apiClientProvider));
});
