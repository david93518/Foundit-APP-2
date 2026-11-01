import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../../core/services/auth_token_store.dart';

/// 認證狀態結果
class AuthResult {
  final bool success;
  final String token;
  final AppUser? user;
  final String message;
  const AuthResult({
    required this.success,
    this.token = '',
    this.user,
    this.message = '',
  });
}

abstract class AuthRepository {
  Future<AuthResult> sendOtp(String phone);
  Future<AuthResult> verifyOtp(String phone, String otp);

  /// 第三方 OAuth 登入（Google / LINE）。`provider` 為 `google` 或 `line`，
  /// `token` 為 Google 的 idToken 或 LINE 的 access token。
  Future<AuthResult> oauthLogin({
    required String provider,
    required String token,
    String? name,
    String? avatarUrl,
  });

  Future<AppUser?> getMe();

  Future<AuthResult> invitedLogin(String username, String password) async =>
      const AuthResult(success: false, message: '此模式不支援受邀帳號登入');
  Future<AuthResult> deleteInvitedAccount(
    String username,
    String password,
  ) async => const AuthResult(success: false, message: '此模式沒有可刪除的受邀帳號');

  /// 局部更新個人資料；不傳的欄位後端不會動。
  Future<AppUser?> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  });
  Future<void> logout();
  Future<AuthResult> deleteAccount(String otp);
  Future<AuthResult> deleteGoogleAccount(String idToken) async =>
      const AuthResult(success: false, message: '體驗模式沒有可刪除的帳號');
  Future<AuthResult> report({
    required String targetType,
    required String targetId,
    required String reason,
  });
  Future<bool> isLoggedIn();
  Future<AppUser?> cachedUser();
}

/// Mock 實作：直接回假資料，適合 UI 開發期
class MockAuthRepository extends AuthRepository {
  MockAuthRepository(this._prefs);
  final SharedPreferences _prefs;

  AppUser _makeUser(String phone) => AppUser(
    id: 'u1',
    phone: phone,
    name: 'David',
    avatarUrl: 'https://i.pravatar.cc/150?img=5',
    points: 350,
    isVerified: true,
    createdAt: DateTime.now(),
  );

  @override
  Future<AuthResult> sendOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const AuthResult(success: true, message: '驗證碼已送出（Mock）');
  }

  @override
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (otp.length != 6) {
      return const AuthResult(success: false, message: '驗證碼格式錯誤');
    }
    final user = _makeUser(phone);
    await AuthTokenStore.write(_prefs, 'mock_token_xyz');
    await _prefs.setString(AppConstants.prefUserId, user.id);
    await _prefs.setString(AppConstants.prefUserName, user.name);
    await _prefs.setString(AppConstants.prefUserAvatar, user.avatarUrl);
    await _prefs.setString(AppConstants.prefUserPhone, user.phone);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, true);
    return AuthResult(
      success: true,
      token: 'mock_token_xyz',
      user: user,
      message: '登入成功',
    );
  }

  @override
  Future<AuthResult> oauthLogin({
    required String provider,
    required String token,
    String? name,
    String? avatarUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final user = AppUser(
      id: 'u_${provider}_mock',
      phone: '',
      name: (name?.isNotEmpty ?? false)
          ? name!
          : '${provider.toUpperCase()} 使用者',
      avatarUrl: avatarUrl ?? 'https://i.pravatar.cc/150?img=12',
      points: 100,
      isVerified: true,
      createdAt: DateTime.now(),
    );
    await AuthTokenStore.write(_prefs, 'mock_${provider}_token');
    await _prefs.setString(AppConstants.prefUserId, user.id);
    await _prefs.setString(AppConstants.prefUserName, user.name);
    await _prefs.setString(AppConstants.prefUserAvatar, user.avatarUrl);
    await _prefs.setString(AppConstants.prefUserPhone, user.phone);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, true);
    return AuthResult(
      success: true,
      token: 'mock_${provider}_token',
      user: user,
      message: '$provider 登入成功（Mock）',
    );
  }

  @override
  Future<AppUser?> getMe() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return cachedUser();
  }

  @override
  Future<AppUser?> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (name != null && name.isNotEmpty) {
      await _prefs.setString(AppConstants.prefUserName, name);
    }
    if (avatarUrl != null) {
      await _prefs.setString(AppConstants.prefUserAvatar, avatarUrl);
    }
    if (bio != null) await _prefs.setString('user_bio', bio);
    if (email != null) await _prefs.setString('user_email', email);
    return cachedUser();
  }

  @override
  Future<void> logout() async {
    await AuthTokenStore.clear(_prefs);
    await _prefs.remove(AppConstants.prefUserId);
    await _prefs.remove(AppConstants.prefUserName);
    await _prefs.remove(AppConstants.prefUserAvatar);
    await _prefs.remove(AppConstants.prefUserPhone);
    await _prefs.remove('user_bio');
    await _prefs.remove('user_email');
    await _prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  @override
  Future<AuthResult> deleteAccount(String otp) async {
    return const AuthResult(success: false, message: '體驗模式沒有可刪除的帳號');
  }

  @override
  Future<AuthResult> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    return const AuthResult(success: false, message: '體驗模式不會送出檢舉');
  }

  @override
  Future<bool> isLoggedIn() async =>
      _prefs.getBool(AppConstants.prefIsLoggedIn) ?? false;

  @override
  Future<AppUser?> cachedUser() async {
    final id = _prefs.getString(AppConstants.prefUserId);
    if (id == null || id.isEmpty) return null;
    return AppUser(
      id: id,
      phone: _prefs.getString(AppConstants.prefUserPhone) ?? '',
      name: _prefs.getString(AppConstants.prefUserName) ?? '',
      avatarUrl: _prefs.getString(AppConstants.prefUserAvatar) ?? '',
      bio: _prefs.getString('user_bio') ?? '',
      email: _prefs.getString('user_email') ?? '',
      points: 350,
      isVerified: true,
      createdAt: DateTime.now(),
    );
  }
}

/// 真實 API 實作（NestJS 後端）
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._prefs);
  final ApiClient _api;
  final SharedPreferences _prefs;

  @override
  Future<AuthResult> invitedLogin(String username, String password) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/invited-login',
        data: {'username': username, 'password': password},
      );
      final data = res.data ?? {};
      final token = data['token']?.toString() ?? '';
      final userJson = data['user'] as Map<String, dynamic>?;
      if (data['success'] != true || token.isEmpty || userJson == null) {
        return const AuthResult(success: false, message: '登入未完成，請稍後重試。');
      }
      final user = AppUser.fromJson(userJson);
      await _persistSession(token, user);
      return AuthResult(success: true, token: token, user: user);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: '無法登入，請確認帳號、密碼、邀請期限及網路連線。',
      );
    }
  }

  @override
  Future<AuthResult> deleteInvitedAccount(
    String username,
    String password,
  ) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/users/me/delete-invited',
        data: {'username': username, 'password': password},
      );
      return AuthResult(
        success: res.data?['success'] == true,
        message: res.data?['message']?.toString() ?? '',
      );
    } catch (_) {
      return const AuthResult(success: false, message: '帳號尚未刪除，請確認密碼及網路連線。');
    }
  }

  @override
  Future<AuthResult> deleteGoogleAccount(String idToken) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/users/me/delete-google',
        data: {'idToken': idToken},
      );
      return AuthResult(
        success: res.data?['success'] == true,
        message: res.data?['message']?.toString() ?? '',
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        message: '刪除未完成，請確認使用原本的 Google 帳號後重試。',
      );
    }
  }

  @override
  Future<AuthResult> sendOtp(String phone) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/send-otp',
        data: {'phone': phone},
      );
      final d = res.data ?? {};
      return AuthResult(
        success: d['success'] as bool? ?? false,
        message: d['message']?.toString() ?? '',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendly(e, '驗證碼暫時無法寄出，請稍後再試'));
    }
  }

  @override
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {'phone': phone, 'otp': otp},
      );
      final d = res.data ?? {};
      final success = d['success'] as bool? ?? false;
      final token = d['token']?.toString() ?? '';
      final userJson = d['user'] as Map<String, dynamic>?;
      final user = userJson == null ? null : AppUser.fromJson(userJson);

      if (success && token.isNotEmpty && user != null) {
        await _persistSession(token, user);
      }

      return AuthResult(
        success: success,
        token: token,
        user: user,
        message: d['message']?.toString() ?? '',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendly(e, '登入失敗，請確認後再試'));
    }
  }

  @override
  Future<AuthResult> oauthLogin({
    required String provider,
    required String token,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/oauth/$provider',
        data: {
          'token': token,
          'provider': provider,
          if (name != null) 'name': name,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        },
      );
      final d = res.data ?? {};
      final success = d['success'] as bool? ?? false;
      final accessToken = d['token']?.toString() ?? '';
      final userJson = d['user'] as Map<String, dynamic>?;
      final user = userJson == null ? null : AppUser.fromJson(userJson);

      if (success && accessToken.isNotEmpty && user != null) {
        await _persistSession(accessToken, user);
      }

      return AuthResult(
        success: success,
        token: accessToken,
        user: user,
        message: d['message']?.toString() ?? '',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendly(e, '第三方登入失敗，請稍後再試'));
    }
  }

  @override
  Future<AppUser?> getMe() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/users/me');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final user = AppUser.fromJson(data);
      // 同步本地快取（Profile / Home 沒網時也有最新資料可看）
      await _persistUserCache(user);
      return user;
    } on DioException catch (e) {
      // 401 已由 ApiClient 攔截器清掉 token，這裡只要回 null 讓上層去處理
      if (e.response?.statusCode == 401) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser?> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (bio != null) body['bio'] = bio;
    if (email != null) body['email'] = email;
    if (body.isEmpty) return getMe();

    final res = await _api.patch<Map<String, dynamic>>('/users/me', data: body);
    final data = res.data?['data'] as Map<String, dynamic>?;
    final user = data == null ? null : AppUser.fromJson(data);
    if (user != null) {
      await _persistUserCache(user);
    }
    return user;
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await AuthTokenStore.clear(_prefs);
    await _prefs.remove(AppConstants.prefUserId);
    await _prefs.remove(AppConstants.prefUserName);
    await _prefs.remove(AppConstants.prefUserAvatar);
    await _prefs.remove(AppConstants.prefUserPhone);
    await _prefs.remove('user_email');
    await _prefs.remove('user_bio');
    await _prefs.remove('user_points');
    await _prefs.remove('user_is_verified');
    // 同一支手機換人登入時，不留下前一位的搜尋紀錄與未送出的聊天草稿。
    await _prefs.remove(AppConstants.prefRecentSearches);
    for (final key in _prefs.getKeys().where((key) => key.startsWith('chat_draft:')).toList()) {
      await _prefs.remove(key);
    }
    await _prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  @override
  Future<AuthResult> deleteAccount(String otp) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/users/me/delete',
        data: {'otp': otp},
      );
      final success = res.data?['success'] as bool? ?? false;
      if (success) await logout();
      return AuthResult(
        success: success,
        message: res.data?['message']?.toString() ?? '',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendly(e, '帳號尚未刪除，請稍後再試'));
    }
  }

  @override
  Future<AuthResult> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/reports',
        data: {
          'targetType': targetType,
          'targetId': targetId,
          'reason': reason,
        },
      );
      return AuthResult(
        success: res.data?['success'] as bool? ?? false,
        message: res.data?['message']?.toString() ?? '已送出檢舉',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendly(e, '檢舉尚未送出，請稍後再試'));
    }
  }

  @override
  Future<bool> isLoggedIn() async =>
      _prefs.getBool(AppConstants.prefIsLoggedIn) ?? false;

  @override
  Future<AppUser?> cachedUser() async {
    final id = _prefs.getString(AppConstants.prefUserId);
    if (id == null || id.isEmpty) return null;
    return AppUser(
      id: id,
      phone: _prefs.getString(AppConstants.prefUserPhone) ?? '',
      name: _prefs.getString(AppConstants.prefUserName) ?? '',
      avatarUrl: _prefs.getString(AppConstants.prefUserAvatar) ?? '',
      email: _prefs.getString('user_email') ?? '',
      bio: _prefs.getString('user_bio') ?? '',
      points: _prefs.getInt('user_points') ?? 0,
      isVerified: _prefs.getBool('user_is_verified') ?? false,
      createdAt: DateTime.now(),
    );
  }

  /// 只顯示伺服器給使用者看的訊息；例外的原始內容（內部網址、堆疊）不出現在畫面上。
  String _friendly(Object error, String fallback) => apiErrorMessage(error) ?? fallback;

  Future<void> _persistSession(String token, AppUser user) async {
    await AuthTokenStore.write(_prefs, token);
    await _persistUserCache(user);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, true);
  }

  Future<void> _persistUserCache(AppUser user) async {
    await _prefs.setString(AppConstants.prefUserId, user.id);
    await _prefs.setString(AppConstants.prefUserName, user.name);
    await _prefs.setString(AppConstants.prefUserAvatar, user.avatarUrl);
    await _prefs.setString(AppConstants.prefUserPhone, user.phone);
    await _prefs.setString('user_email', user.email);
    await _prefs.setString('user_bio', user.bio);
    await _prefs.setInt('user_points', user.points);
    await _prefs.setBool('user_is_verified', user.isVerified);
  }
}
