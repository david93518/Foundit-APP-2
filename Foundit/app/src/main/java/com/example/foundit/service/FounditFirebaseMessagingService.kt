package com.example.foundit.service

/**
 * Firebase Cloud Messaging (FCM) 推播服務
 *
 * ⚠️ 啟用步驟：
 * 1. 至 https://console.firebase.google.com 建立 Firebase 專案
 * 2. 下載 google-services.json 放入 app/ 目錄
 * 3. 在 app/build.gradle.kts 中取消 Firebase 依賴的註解
 * 4. 在 build.gradle.kts (root) 中新增：
 *    alias(libs.plugins.google.services) apply false
 * 5. 在 app/build.gradle.kts plugins 中新增：
 *    alias(libs.plugins.google.services)
 * 6. 取消下方程式碼的多行註解
 */

/*
import com.example.foundit.util.NotificationHelper
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FounditFirebaseMessagingService : FirebaseMessagingService() {

    /**
     * 收到 FCM 推播訊息
     * 後端推播格式（data payload）：
     * {
     *   "type": "ai_match" | "new_message" | "nearby_item" | "qr_scan" | "general",
     *   "title": "通知標題",
     *   "message": "通知內容",
     *   "item_id": "相關物品 ID（可選）",
     *   "chat_id": "相關聊天室 ID（可選）",
     *   "sender_name": "發送者姓名（訊息通知用）"
     * }
     */
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: "general"
        val title = data["title"] ?: message.notification?.title ?: "找得到"
        val body = data["message"] ?: message.notification?.body ?: ""
        val itemId = data["item_id"]
        val chatId = data["chat_id"]
        val senderName = data["sender_name"] ?: "使用者"

        when (type) {
            "ai_match" -> {
                val sourceTitle = data["source_title"] ?: "您的物品"
                NotificationHelper.showAiMatchNotification(
                    context = applicationContext,
                    matchedItemTitle = body,
                    sourceItemTitle = sourceTitle,
                    matchedItemId = itemId
                )
            }
            "new_message" -> {
                NotificationHelper.showMessageNotification(
                    context = applicationContext,
                    senderName = senderName,
                    messageContent = body,
                    chatId = chatId
                )
            }
            "nearby_item" -> {
                val locationName = data["location_name"] ?: "附近"
                NotificationHelper.showNearbyItemNotification(
                    context = applicationContext,
                    itemTitle = title,
                    locationName = locationName,
                    itemId = itemId
                )
            }
            "qr_scan" -> {
                NotificationHelper.showQrScannedNotification(
                    context = applicationContext,
                    itemName = body
                )
            }
            else -> {
                NotificationHelper.showGeneralNotification(
                    context = applicationContext,
                    title = title,
                    message = body
                )
            }
        }
    }

    /**
     * FCM Token 更新時呼叫
     * 需將新 Token 同步到後端 API
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // TODO: 呼叫 API 更新 FCM token
        // viewModelScope.launch { api.updateFcmToken(token) }
        android.util.Log.d("FCM", "New FCM token: $token")
    }
}
*/

/**
 * FCM Token 取得工具（啟用 Firebase 後可使用）
 */
object FcmTokenManager {

    /**
     * 取得目前 FCM Token（需先啟用 Firebase）
     */
    fun getFcmToken(onSuccess: (String) -> Unit, onError: (Exception) -> Unit = {}) {
        // 啟用 Firebase 後取消下方註解：
        // com.google.firebase.messaging.FirebaseMessaging.getInstance().token
        //     .addOnSuccessListener { onSuccess(it) }
        //     .addOnFailureListener { onError(it) }
        onError(IllegalStateException("Firebase 尚未設定，請參閱 FounditFirebaseMessagingService.kt 中的啟用步驟"))
    }
}
