package com.example.foundit.data.model

import com.google.gson.annotations.SerializedName

enum class NotificationType(val label: String) {
    AI_MATCH("AI 配對"),
    NEW_MESSAGE("新訊息"),
    NEARBY_ITEM("附近物品"),
    QR_SCAN("QR 掃描"),
    REWARD("賞金"),
    SYSTEM("系統通知")
}

data class Notification(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("user_id")
    val userId: String = "",

    @SerializedName("type")
    val type: NotificationType = NotificationType.SYSTEM,

    @SerializedName("title")
    val title: String = "",

    @SerializedName("content")
    val content: String = "",

    @SerializedName("item_id")
    val itemId: String? = null,

    @SerializedName("chat_id")
    val chatId: String? = null,

    @SerializedName("is_read")
    val isRead: Boolean = false,

    @SerializedName("created_at")
    val createdAt: Long = System.currentTimeMillis()
)
