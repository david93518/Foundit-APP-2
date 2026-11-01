import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'auth_token_store.dart';

/// A TestFlight update keeps preferences. Demo credentials must never survive
/// the transition to the real backend or make the login button disappear.
Future<void> clearDemoSession(SharedPreferences prefs) async {
  final token = AuthTokenStore.read(prefs) ?? '';
  if (!token.startsWith('mock_')) return;
  await AuthTokenStore.clear(prefs);
  for (final key in [
    AppConstants.prefUserId,
    AppConstants.prefUserName,
    AppConstants.prefUserPhone,
    AppConstants.prefUserAvatar,
    AppConstants.prefIsLoggedIn,
    'user_email',
    'user_bio',
    'user_points',
    'user_is_verified',
  ]) {
    await prefs.remove(key);
  }
}
