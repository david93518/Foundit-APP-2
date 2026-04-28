import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import 'core_providers.dart';

/// Auth 全域狀態
class AuthState {
  final bool loading;
  final AppUser? user;
  final String? error;
  final bool otpSending;
  final bool otpSent;

  const AuthState({
    this.loading = false,
    this.user,
    this.error,
    this.otpSending = false,
    this.otpSent = false,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    bool? loading,
    AppUser? user,
    bool clearUser = false,
    String? error,
    bool clearError = false,
    bool? otpSending,
    bool? otpSent,
  }) =>
      AuthState(
        loading: loading ?? this.loading,
        user: clearUser ? null : (user ?? this.user),
        error: clearError ? null : (error ?? this.error),
        otpSending: otpSending ?? this.otpSending,
        otpSent: otpSent ?? this.otpSent,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }
  final AuthRepository _repo;

  Future<void> _init() async {
    final user = await _repo.cachedUser();
    state = state.copyWith(user: user);
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(otpSending: true, clearError: true);
    final r = await _repo.sendOtp(phone);
    state = state.copyWith(
      otpSending: false,
      otpSent: r.success,
      error: r.success ? null : r.message,
    );
    return r.success;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(loading: true, clearError: true);
    final r = await _repo.verifyOtp(phone, otp);
    state = state.copyWith(
      loading: false,
      user: r.user,
      error: r.success ? null : r.message,
    );
    return r.success;
  }

  /// 第三方 OAuth 登入（Google / LINE）
  Future<bool> oauthLogin({
    required String provider,
    required String token,
    String? name,
    String? avatarUrl,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    final r = await _repo.oauthLogin(
      provider: provider,
      token: token,
      name: name,
      avatarUrl: avatarUrl,
    );
    state = state.copyWith(
      loading: false,
      user: r.user,
      error: r.success ? null : r.message,
    );
    return r.success;
  }

  Future<void> refresh() async {
    final user = await _repo.getMe();
    if (user != null) state = state.copyWith(user: user);
  }

  /// 局部更新；不傳的欄位後端不會動。
  /// 回傳是否成功。
  Future<bool> updateProfile({
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final user = await _repo.updateProfile(
        name: name,
        avatarUrl: avatarUrl,
        bio: bio,
        email: email,
      );
      state = state.copyWith(loading: false, user: user);
      return user != null;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = state.copyWith(clearUser: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
