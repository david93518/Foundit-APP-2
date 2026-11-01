import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves an existing plaintext token into secure storage and keeps it out of prefs', () async {
    FlutterSecureStorage.setMockInitialValues({AppConstants.prefAuthToken: 'stale-from-old-install'});
    SharedPreferences.setMockInitialValues({AppConstants.prefAuthToken: 'session-from-1.0.0'});
    final prefs = await SharedPreferences.getInstance();

    await AuthTokenStore.enableSecureStorage(prefs);

    expect(AuthTokenStore.read(prefs), 'session-from-1.0.0');
    expect(prefs.getString(AppConstants.prefAuthToken), isNull);
    expect(await const FlutterSecureStorage().read(key: AppConstants.prefAuthToken), 'session-from-1.0.0');

    await AuthTokenStore.write(prefs, 'next-session');
    expect(AuthTokenStore.read(prefs), 'next-session');
    expect(prefs.getString(AppConstants.prefAuthToken), isNull);

    await AuthTokenStore.clear(prefs);
    expect(AuthTokenStore.read(prefs), isNull);
    expect(await const FlutterSecureStorage().read(key: AppConstants.prefAuthToken), isNull);
  });

  test('a fresh install does not resurrect a keychain token left by a deleted app', () async {
    FlutterSecureStorage.setMockInitialValues({AppConstants.prefAuthToken: 'left-in-keychain'});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await AuthTokenStore.enableSecureStorage(prefs);

    expect(AuthTokenStore.read(prefs), isNull);
  });

  test('release builds refuse a cleartext API origin', () {
    expect(() => AppConstants.assertSecureTransport(release: true), returnsNormally);
    expect(AppConstants.baseUrl, startsWith('https://'));
    expect(AppConstants.socketHost, startsWith('https://'));
  });
  test('Web tokens exist only in memory and a reload clears legacy persisted login', () async {
    SharedPreferences.setMockInitialValues({AppConstants.prefAuthToken: 'legacy-web', AppConstants.prefIsLoggedIn: true});
    final prefs = await SharedPreferences.getInstance();
    await AuthTokenStore.enableMemoryStorage(prefs);
    expect(AuthTokenStore.read(prefs), isNull);
    expect(prefs.getString(AppConstants.prefAuthToken), isNull);
    await AuthTokenStore.write(prefs, 'active-web');
    expect(AuthTokenStore.read(prefs), 'active-web');
    expect(prefs.getString(AppConstants.prefAuthToken), isNull);
    await AuthTokenStore.enableMemoryStorage(prefs);
    expect(AuthTokenStore.read(prefs), isNull);
  });
}
