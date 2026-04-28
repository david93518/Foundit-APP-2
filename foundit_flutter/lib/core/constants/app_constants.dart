/// 全域常數
class AppConstants {
  AppConstants._();

  /// 切換至 true 使用本地 Mock 資料（不連後端，方便看 UI）
  /// 後端跑起來後再改回 false
  /// ▶ 預設為 false：上架版本連線到 NestJS 後端
  static const bool useMock = false;

  /// 後端 API 基底位址
  ///
  /// 上線版本可透過 build flag 注入，例如：
  /// ```
  /// flutter build apk --dart-define=API_BASE_URL=https://api.foundit.com.tw/api/v1 \
  ///                   --dart-define=SOCKET_HOST=https://api.foundit.com.tw
  /// ```
  /// 沒注入時的 fallback：
  /// - Android 模擬器：10.0.2.2 指向主機 localhost
  /// - iOS 模擬器 / Web：localhost
  /// - 實機測試：改成電腦 IP
  /// 實機測試：把 192.168.x.x 改成你電腦在區域網路的實際 IP
  /// 上線版本透過 --dart-define=API_BASE_URL=https://... 注入
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.100:3000/api/v1',
  );

  static const String socketHost = String.fromEnvironment(
    'SOCKET_HOST',
    defaultValue: 'http://192.168.1.100:3000',
  );
  static const String socketChatNamespace = '/chat';

  /// 是否為 release / 上架構建（給診斷訊息用，會自動隱藏除錯資訊）
  static const bool isProduction = bool.fromEnvironment(
    'PROD',
    defaultValue: false,
  );

  /// Google 登入：網頁應用程式 OAuth 用戶端 ID（給 idToken 用）
  /// 上線版可用 --dart-define=GOOGLE_WEB_CLIENT_ID=... 覆蓋
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '992454620238-n6au0m0d8vjj6mghn6mnoeg7sbb3v9r7.apps.googleusercontent.com',
  );

  static const String appName = '找得到';
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
    '黑色', '白色', '灰色', '紅色', '橘色',
    '黃色', '綠色', '藍色', '紫色', '棕色', '粉紅色', '其他',
  ];

  static const List<String> areas = [
    '全部地區',
    '台北市', '新北市', '桃園市', '台中市', '台南市',
    '高雄市', '基隆市', '新竹市', '嘉義市',
    '宜蘭縣', '花蓮縣', '台東縣',
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
