import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// 通用 Dio 封裝；自動附帶 JWT 並統一處理錯誤。
///
/// - 401 會清空本地登入資訊並透過 [onUnauthorized] 通知 UI 層
///   （由 router 或 main 訂閱，導向 /login）
/// - 5xx / 網路錯誤統一拋出，由 caller 顯示 SnackBar
class ApiClient {
  ApiClient(this._prefs)
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _prefs.getString(AppConstants.prefAuthToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await _handleUnauthorized();
          }
          return handler.next(e);
        },
      ),
    );
  }

  final SharedPreferences _prefs;
  final Dio _dio;

  /// 全域 401 監聽（router 訂閱，導去 /login）
  static final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();
  static Stream<void> get onUnauthorized => _unauthorized.stream;

  Future<void> _handleUnauthorized() async {
    await _prefs.remove(AppConstants.prefAuthToken);
    await _prefs.setBool(AppConstants.prefIsLoggedIn, false);
    if (!_unauthorized.isClosed) {
      _unauthorized.add(null);
    }
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path,
          {Object? data, Map<String, dynamic>? query}) =>
      _dio.post<T>(path, data: data, queryParameters: query);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
