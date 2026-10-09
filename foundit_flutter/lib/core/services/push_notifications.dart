import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/api/api_client.dart';
import '../constants/app_constants.dart';

/// App 在前景時收到的聊天推播；由畫面決定要不要提示（正在看這個對話就不打擾）。
class ChatPush {
  const ChatPush({required this.chatId, this.title = '', this.body = ''});
  final String chatId;
  final String title;
  final String body;
}

/// FCM 推播：登入後註冊裝置 token，點通知打開對應的聊天室。
///
/// 只在 Android / iOS 真機版啟用。Firebase 未設定（例如 iOS 尚未放入
/// GoogleService-Info.plist）時安靜停用，聊天仍可在 App 內使用。
class PushNotifications {
  PushNotifications(this._api);
  final ApiClient _api;

  final _opened = StreamController<String>.broadcast();
  final _foreground = StreamController<ChatPush>.broadcast();
  StreamSubscription<String>? _refreshSub;
  String? _registeredFor;
  bool _ready = false;

  /// 使用者點了通知（App 從背景或關閉狀態被打開）。
  Stream<String> get openedChats => _opened.stream;

  /// App 在前景時收到的聊天推播。
  Stream<ChatPush> get foreground => _foreground.stream;

  /// 冷啟動時點的那則通知；畫面掛上監聽後再取用一次。
  String? pendingOpen;

  static bool get supported =>
      !kIsWeb &&
      !AppConstants.useMock &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!supported || _ready) return;
    final options = _options();
    if (defaultTargetPlatform == TargetPlatform.iOS && options == null) {
      if (kDebugMode) debugPrint('推播停用：iOS build 未帶入 FIREBASE_IOS_API_KEY / FIREBASE_IOS_APP_ID');
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
    } catch (error) {
      if (kDebugMode) debugPrint('推播停用：Firebase 未設定（$error）');
      return;
    }
    _ready = true;
    final messaging = FirebaseMessaging.instance;
    // iOS 前景只更新角標；提示由 App 內的訊息條負責。
    await messaging.setForegroundNotificationPresentationOptions(badge: true);
    FirebaseMessaging.onMessage.listen((message) {
      final chatId = _chatId(message);
      if (chatId == null) return;
      _foreground.add(ChatPush(
        chatId: chatId,
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      ));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final chatId = _chatId(message);
      if (chatId != null) _opened.add(chatId);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null) pendingOpen = _chatId(initial);
  }

  /// 登入（或啟動時已登入）後呼叫。會在第一次時詢問通知權限。
  Future<void> registerFor(String userId) async {
    if (!_ready || _registeredFor == userId) return;
    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _deviceToken(messaging);
      if (token == null) return;
      await _upload(token);
      _registeredFor = userId;
      _refreshSub ??= messaging.onTokenRefresh.listen((next) {
        if (_registeredFor != null) unawaited(_upload(next).catchError((_) {}));
      });
    } catch (error) {
      if (kDebugMode) debugPrint('推播註冊失敗：$error');
    }
  }

  /// 登出時呼叫。後端登出已清除帳號上的 token；這裡再讓裝置換一組新 token，
  /// 下一個登入的帳號不會沿用舊的。
  Future<void> unregister() async {
    if (!_ready || _registeredFor == null) return;
    _registeredFor = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _upload(String token) =>
      _api.patch<Map<String, dynamic>>('/auth/fcm-token', data: {'fcm_token': token});

  /// iOS 要等 APNs token 到位才拿得到 FCM token。
  Future<String?> _deviceToken(FirebaseMessaging messaging) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var i = 0; i < 5 && await messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (await messaging.getAPNSToken() == null) return null;
    }
    return messaging.getToken();
  }

  /// Android 由 google-services 外掛提供設定，回傳 null。
  static FirebaseOptions? _options() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    if (AppConstants.firebaseIosApiKey.isEmpty ||
        AppConstants.firebaseIosAppId.isEmpty) {
      return null;
    }
    return const FirebaseOptions(
      apiKey: AppConstants.firebaseIosApiKey,
      appId: AppConstants.firebaseIosAppId,
      messagingSenderId: AppConstants.firebaseSenderId,
      projectId: AppConstants.firebaseProjectId,
      iosBundleId: AppConstants.iosBundleId,
    );
  }

  static String? _chatId(RemoteMessage message) {
    final id = message.data['chat_id']?.toString() ?? '';
    return id.isEmpty ? null : id;
  }
}
