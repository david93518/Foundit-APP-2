import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../api/api_client.dart';
import '../models/user.dart';

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

  /// 局部更新個人資料；不傳的欄位後端不會動。
  Future<AppUser?> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  });
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<AppUser?> cachedUser();
}

/// Mock 實作：直接回假資料，適合 UI 開發期
class MockAuthRepository implements AuthRepository {
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
    await _prefs.setString(AppConstants.prefAuthToken, 'mock_token_xyz');
    await _prefs.setString(AppConstants.prefUserId, user.id);
    await _prefs.setString(AppConstants.prefUserName, user.name);
    await _prefs.setString(AppConstants.prefUserAvatar, user.avatarUrl);
    await _prefs.setString(AppConstants.prefUserPhone, user.phone);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, true);
    return AuthResult(
        success: true, token: 'mock_token_xyz', user: user, message: '登入成功');
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
      name: (name?.isNotEmpty ?? false) ? name! : '${provider.toUpperCase()} 使用者',
      avatarUrl: avatarUrl ?? 'https://i.pravatar.cc/150?img=12',
      points: 100,
      isVerified: true,
      createdAt: DateTime.now(),
    );
    await _prefs.setString(AppConstants.prefAuthToken, 'mock_${provider}_token');
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
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await _prefs.setString(AppConstants.prefUserAvatar, avatarUrl);
    }
    return cachedUser();
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(AppConstants.prefAuthToken);
    await _prefs.remove(AppConstants.prefUserId);
    await _prefs.remove(AppConstants.prefUserName);
    await _prefs.remove(AppConstants.prefUserAvatar);
    await _prefs.remove(AppConstants.prefUserPhone);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, false);
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
      return AuthResult(success: false, message: e.toString());
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
      return AuthResult(success: false, message: e.toString());
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
      return AuthResult(success: false, message: '第三方登入失敗：$e');
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

    final res = await _api.patch<Map<String, dynamic>>(
      '/users/me',
      data: body,
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    final user = data == null ? null : AppUser.fromJson(data);
    if (user != null) {
      await _persistUserCache(user);
    }
    return user;
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(AppConstants.prefAuthToken);
    await _prefs.remove(AppConstants.prefUserId);
    await _prefs.remove(AppConstants.prefUserName);
    await _prefs.remove(AppConstants.prefUserAvatar);
    await _prefs.remove(AppConstants.prefUserPhone);
    await _prefs.remove('user_email');
    await _prefs.remove('user_bio');
    await _prefs.remove('user_points');
    await _prefs.remove('user_is_verified');
    await _prefs.setBool(AppConstants.prefIsLoggedIn, false);
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

  Future<void> _persistSession(String token, AppUser user) async {
    await _prefs.setString(AppConstants.prefAuthToken, token);
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
