package com.example.foundit.ui.navigation

import android.util.Base64

/** App 內所有導航路由定義 */
sealed class Screen(val route: String) {

    // ── 啟動 / 認證 ──
    object Splash : Screen("splash")
    object Login : Screen("login")
    object Otp : Screen("otp/{phone}") {
        fun createRoute(phone: String) = "otp/$phone"
    }

    // ── 底部主導航 ──
    object Home : Screen("home")
    object Search : Screen("search")
    object Map : Screen("map")
    object ChatList : Screen("chat_list")
    object Profile : Screen("profile")

    // ── 物品相關 ──
    object AddItem : Screen("add_item/{type}") {
        fun createRoute(type: String) = "add_item/$type"
    }
    object ItemDetail : Screen("item_detail/{itemId}") {
        fun createRoute(itemId: String) = "item_detail/$itemId"
    }
    object EditItem : Screen("edit_item/{itemId}") {
        fun createRoute(itemId: String) = "edit_item/$itemId"
    }

    // ── 聊天 ──
    object ChatRoom : Screen("chat_room/{chatId}/{itemTitle}/{fromItem}") {
        /**
         * itemTitle 以 Base64(URL_SAFE) 編碼，避免「錢包/皮夾」等含 `/` 的標題拆壞導航路徑。
         * @param fromItem 為 true 時，chatId 為物品 id，進房後會先向後端建立或取得聊天室
         */
        fun createRoute(chatId: String, itemTitle: String, fromItem: Boolean = false): String {
            val titleSeg = if (itemTitle.isBlank()) {
                "_"
            } else {
                Base64.encodeToString(
                    itemTitle.toByteArray(Charsets.UTF_8),
                    Base64.URL_SAFE or Base64.NO_WRAP
                )
            }
            return "chat_room/$chatId/$titleSeg/${if (fromItem) "1" else "0"}"
        }
    }

    // ── QR Code ──
    object Qr : Screen("qr")
    object QrScan : Screen("qr_scan")

    // ── AI 配對 ──
    object AiMatch : Screen("ai_match/{itemId}") {
        fun createRoute(itemId: String) = "ai_match/$itemId"
    }

    // ── 個人資料 ──
    object EditProfile : Screen("edit_profile")

    // ── 其他 ──
    object Notification : Screen("notification")
    object Settings : Screen("settings")
    object Points : Screen("points")
}

/** 底部導航列的項目定義 */
data class BottomNavItem(
    val screen: Screen,
    val labelResId: Int,
    val iconName: String,
)
