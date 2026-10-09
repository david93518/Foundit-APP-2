import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// 登入 token 的唯一存取點。
///
/// 手機上存在 iOS Keychain／Android Keystore 加密儲存：不進裝置備份、不會跟著轉移到新手機，
/// 其他 App 也讀不到。啟動時由 [enableSecureStorage] 一次讀進記憶體，之後同步取用。
/// 單元測試與 Web 預覽不會呼叫 [enableSecureStorage]，因此沿用 SharedPreferences。
class AuthTokenStore {
  AuthTokenStore._();

  static const _key = AppConstants.prefAuthToken;
  static const _marker = 'auth_token_secure_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static bool _secure = false;
  static String? _token;
  static bool _memoryOnly = false;

  /// Web sessions end on reload; bearer tokens never persist in browser storage.
  static Future<void> enableMemoryStorage(SharedPreferences prefs) async {
    _memoryOnly = true;
    _secure = false;
    _token = null;
    await prefs.remove(_key);
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  /// 改用安全儲存，並把舊版放在 SharedPreferences 的 token 搬過去後刪除明文。
  static Future<void> enableSecureStorage(SharedPreferences prefs) async {
    _memoryOnly = false;
    _secure = true;
    final legacy = prefs.getString(_key);
    try {
      // Keychain 在刪除 App 後仍會保留：沒有標記代表新安裝或剛升級，先清掉殘留的舊 token。
      if (!(prefs.getBool(_marker) ?? false)) await _storage.delete(key: _key);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: _key, value: legacy);
      }
      _token = await _storage.read(key: _key);
    } catch (_) {
      // Keystore 損毀或從備份還原後無法解密：視為未登入，絕不退回明文儲存。
      _token = null;
      try {
        await _storage.deleteAll();
      } catch (_) {}
      await prefs.setBool(AppConstants.prefIsLoggedIn, false);
    }
    await prefs.remove(_key);
    await prefs.setBool(_marker, true);
  }

  static String? read(SharedPreferences prefs) =>
      (_secure || _memoryOnly) ? _token : prefs.getString(_key);

  static Future<void> write(SharedPreferences prefs, String token) async {
    if (_memoryOnly) {
      _token = token;
      await prefs.remove(_key);
      return;
    }
    if (!_secure) {
      await prefs.setString(_key, token);
      return;
    }
    _token = token;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // 寫不進安全儲存時只保留在記憶體：這次開著 App 仍可用，重開需要再登入。
    }
  }

  static Future<void> clear(SharedPreferences prefs) async {
    _token = null;
    await prefs.remove(_key);
    if (!_secure) return;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
