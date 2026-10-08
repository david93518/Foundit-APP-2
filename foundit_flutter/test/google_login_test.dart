import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/google_identity_service.dart';
import 'package:foundit/core/services/session_migration.dart';
import 'package:foundit/data/models/user.dart';
import 'package:foundit/data/repositories/auth_repository.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/screens/auth/login_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Identity extends GoogleIdentityService {
  _Identity(this.token);
  final String? token;
  @override
  Future<String?> signIn() async => token;
}

class _Auth extends MockAuthRepository {
  _Auth(super.prefs);
  String? receivedToken;
  @override
  Future<AuthResult> oauthLogin({required String provider, required String token, String? name, String? avatarUrl}) async {
    receivedToken = token;
    return AuthResult(success: true, user: AppUser(id: 'real-account', name: '測試', createdAt: DateTime(2026)));
  }
}

void main() {
  test('real upgrade removes demo identity but preserves unrelated preferences', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefAuthToken: 'mock_token_xyz',
      AppConstants.prefUserId: 'me',
      AppConstants.prefIsLoggedIn: true,
      'draft': 'keep',
    });
    final prefs = await SharedPreferences.getInstance();
    await clearDemoSession(prefs);
    expect(prefs.getString(AppConstants.prefUserId), isNull);
    expect(prefs.getString(AppConstants.prefAuthToken), isNull);
    expect(prefs.getString('draft'), 'keep');
    await prefs.setString(AppConstants.prefAuthToken, 'real-session');
    await clearDemoSession(prefs);
    expect(prefs.getString(AppConstants.prefAuthToken), 'real-session');
  });

  for (final token in <String?>['google-id-token', null]) {
    testWidgets('Google ${token == null ? 'cancellation keeps login' : 'identity reaches API and returns to app'}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _Auth(prefs);
      final router = GoRouter(initialLocation: '/login', routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('探索首頁'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(auth),
        googleIdentityProvider.overrideWithValue(_Identity(token)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('取得驗證碼'), findsNothing);
      await tester.tap(find.text('使用 Google 帳號繼續'));
      await tester.pumpAndSettle();
      expect(auth.receivedToken, token);
      expect(find.text('探索首頁'), token == null ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
