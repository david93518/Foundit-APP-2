import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// A TestFlight update keeps preferences. Demo credentials must never survive
/// the transition to the real backend or make the login button disappear.
Future<void> clearDemoSession(SharedPreferences prefs) async {
  final token = prefs.getString(AppConstants.prefAuthToken) ?? '';
  if (!token.startsWith('mock_')) return;
  for (final key in [
    AppConstants.prefAuthToken,
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
