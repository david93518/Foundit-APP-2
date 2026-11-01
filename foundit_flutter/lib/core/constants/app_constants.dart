/// 全域常數
class AppConstants {
  AppConstants._();

  /// 切換至 true 使用本地 Mock 資料（不連後端，方便看 UI）
  /// 後端跑起來後再改回 false
  /// ▶ 預設為 false：上架版本連線到 NestJS 後端
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// 後端 API 基底位址
  ///
  /// 上線版本可透過 build flag 注入，例如：
  /// ```
  /// flutter build apk --dart-define=API_BASE_URL=https://api.foundit.tw/api/v1 \
  ///                   --dart-define=SOCKET_HOST=https://api.foundit.tw
  /// ```
  /// 沒注入時一律連正式 HTTPS。本機開發請明確注入，例如 Android 模擬器用
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`。
  /// Dart 的 HTTP／Socket 不受 iOS ATS 與 Android cleartext 設定保護：
  /// 預設值若是 http，忘了注入的建置會把 token 以明文送給區網上的任何主機。
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.foundit.tw/api/v1',
  );

  static const String socketHost = String.fromEnvironment(
    'SOCKET_HOST',
    defaultValue: 'https://api.foundit.tw',
  );

  /// release 建置只允許 HTTPS；本機 loopback 與 Android 模擬器的 10.0.2.2 例外，供開發驗證。
  static void assertSecureTransport({required bool release}) {
    if (!release || useMock) return;
    for (final value in [baseUrl, socketHost]) {
      final uri = Uri.parse(value);
      final local = const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
      if (uri.scheme != 'https' && !local) {
        throw StateError('release 建置必須使用 HTTPS：$value');
      }
    }
  }
  static const String socketChatNamespace = '/chat';

  /// 是否在登入頁提供手機驗證碼登入（後端需設定 OTP_DRIVER 簡訊供應商）。
  /// 正式後端目前為 OTP_DRIVER=disabled，因此預設只顯示 Google 登入。
  static const bool enablePhoneLogin = bool.fromEnvironment(
    'PHONE_LOGIN',
    defaultValue: false,
  );

  /// 是否為 release / 上架構建（給診斷訊息用，會自動隱藏除錯資訊）
  static const bool isProduction = bool.fromEnvironment(
    'PROD',
    defaultValue: false,
  );

  /// Google 登入：網頁應用程式 OAuth 用戶端 ID（給 idToken 用）
  /// 上線版可用 --dart-define=GOOGLE_WEB_CLIENT_ID=... 覆蓋
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '992454620238-n6au0m0d8vjj6mghn6mnoeg7sbb3v9r7.apps.googleusercontent.com',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '992454620238-b2g6kvo7lf06eslnqvlt3cu2gqc58ebq.apps.googleusercontent.com',
  );

  /// FCM 推播（Firebase 專案 foundit-873c1）。Android 讀 google-services.json；
  /// iOS 不放 GoogleService-Info.plist，改由 build 參數帶入，未提供時 iOS 推播停用。
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'foundit-873c1',
  );
  static const String firebaseSenderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '324414366919',
  );
  static const String firebaseIosApiKey =
      String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String firebaseIosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String iosBundleId = 'com.david93518.foundit';

  static const String appName = 'FOUND !T';
  static const String appSlogan = '失物共享平台';

  // 預設地圖位置（台北市中心）
  static const double defaultLatitude = 25.0330;
  static const double defaultLongitude = 121.5654;
  static const double defaultZoom = 14.0;
  static const double nearbyRadiusKm = 5.0;

  static const int pageSize = 20;
  static const int initialPage = 1;

  static const int maxMessageLength = 500;
  static const int qrCodeSizePx = 512;

  /// 物品分類（搭配 emoji 作為視覺識別）
  static const List<CategoryMeta> itemCategories = [
    CategoryMeta('錢包/皮夾', '👛'),
    CategoryMeta('手機/平板', '📱'),
    CategoryMeta('鑰匙', '🔑'),
    CategoryMeta('文件/證件', '📄'),
    CategoryMeta('包包/背包', '🎒'),
    CategoryMeta('眼鏡', '👓'),
    CategoryMeta('首飾/飾品', '💎'),
    CategoryMeta('服飾', '👔'),
    CategoryMeta('電子產品', '💻'),
    CategoryMeta('寵物', '🐾'),
    CategoryMeta('交通工具', '🚗'),
    CategoryMeta('其他', '📦'),
  ];

  static const List<String> itemColors = [
    '黑色',
    '白色',
    '灰色',
    '紅色',
    '橘色',
    '黃色',
    '綠色',
    '藍色',
    '紫色',
    '棕色',
    '粉紅色',
    '其他',
  ];

  static const List<String> areas = [
    '全部地區',
    '台北市',
    '新北市',
    '桃園市',
    '台中市',
    '台南市',
    '高雄市',
    '基隆市',
    '新竹市',
    '嘉義市',
    '新竹縣',
    '苗栗縣',
    '彰化縣',
    '南投縣',
    '雲林縣',
    '嘉義縣',
    '屏東縣',
    '宜蘭縣',
    '花蓮縣',
    '台東縣',
    '澎湖縣',
    '金門縣',
    '連江縣',
  ];

  // SharedPreferences keys
  static const String prefAuthToken = 'auth_token';
  static const String prefUserId = 'user_id';
  static const String prefUserName = 'user_name';
  static const String prefUserAvatar = 'user_avatar';
  static const String prefUserPhone = 'user_phone';
  static const String prefIsLoggedIn = 'is_logged_in';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefRecentSearches = 'recent_searches';

  // 積分事件
  static const int pointsFoundItem = 50;
  static const int pointsMatchSuccess = 100;
  static const int pointsDailyLogin = 5;
}

class CategoryMeta {
  final String name;
  final String emoji;
  const CategoryMeta(this.name, this.emoji);
}
