package com.example.foundit.util

object Constants {
    // false：連真實 Nest API + PostgreSQL；true：僅記憶體 Mock（不進資料庫）
    const val USE_MOCK = false

    // 本機開發（Android 模擬器用 10.0.2.2 存取 host 的 localhost）
    // 實體機測試請改為電腦 IP，例如 "http://192.168.1.100:3000/api/v1/"
    const val BASE_URL = "http://10.0.2.2:3000/api/v1/"

    /** API 根（不含 /api/v1），供上傳圖片 URL 替換、WebSocket 連線 */
    val API_ORIGIN: String
        get() = BASE_URL.trimEnd('/').removeSuffix("/api/v1")

    // DataStore Keys
    const val PREF_AUTH_TOKEN = "auth_token"
    const val PREF_USER_ID = "user_id"
    const val PREF_USER_NAME = "user_name"
    const val PREF_USER_AVATAR = "user_avatar"
    const val PREF_USER_PHONE = "user_phone"
    const val PREF_IS_LOGGED_IN = "is_logged_in"
    const val PREF_ONBOARDING_DONE = "onboarding_done"

    // Google Maps
    const val DEFAULT_LATITUDE = 25.0330  // 台北市中心
    const val DEFAULT_LONGITUDE = 121.5654
    const val DEFAULT_ZOOM = 13f
    const val NEARBY_RADIUS_KM = 5.0

    // AI 配對
    const val AI_MATCH_TIMEOUT_SECONDS = 30L
    const val AI_MATCH_MAX_RESULTS = 10

    // 分頁
    const val PAGE_SIZE = 20
    const val INITIAL_PAGE = 1

    // 聊天（Socket.IO namespace，實際連線位址由 API_ORIGIN + "/chat"）
    const val MAX_MESSAGE_LENGTH = 500

    // QR Code
    const val QR_CODE_SIZE_PX = 512
    const val QR_SCAN_DEEP_LINK = "https://foundit.com.tw/qr/"

    // 物品分類
    val ITEM_CATEGORIES = listOf(
        "錢包/皮夾",
        "手機/平板",
        "鑰匙",
        "文件/證件",
        "包包/背包",
        "眼鏡",
        "首飾/飾品",
        "服飾",
        "電子產品",
        "寵物",
        "交通工具",
        "其他"
    )

    // 物品顏色
    val ITEM_COLORS = listOf(
        "黑色", "白色", "灰色", "紅色", "橘色",
        "黃色", "綠色", "藍色", "紫色", "棕色", "粉紅色", "其他"
    )

    // 地區列表
    val AREAS = listOf(
        "全部地區",
        "台北市", "新北市", "桃園市", "台中市", "台南市",
        "高雄市", "基隆市", "新竹市", "嘉義市",
        "宜蘭縣", "花蓮縣", "台東縣"
    )

    // OAuth 提供者
    const val PROVIDER_GOOGLE = "google"
    const val PROVIDER_LINE = "line"

    // 積分事件
    const val POINTS_FOUND_ITEM = 50      // 登記撿到物
    const val POINTS_MATCH_SUCCESS = 100  // 成功配對
    const val POINTS_DAILY_LOGIN = 5      // 每日登入
}
