package com.example.foundit.util

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.foundit.MainActivity
import com.example.foundit.R

/**
 * 本地通知管理工具
 * 負責建立通知頻道、發送各類系統通知
 */
object NotificationHelper {

    // ── 通知頻道 ID ──
    const val CHANNEL_AI_MATCH = "channel_ai_match"
    const val CHANNEL_MESSAGES = "channel_messages"
    const val CHANNEL_NEARBY = "channel_nearby_items"
    const val CHANNEL_GENERAL = "channel_general"

    // ── 通知 ID ──
    private var notifIdCounter = 1000

    // ── 初始化通知頻道（在 Application.onCreate 呼叫）──

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannels(
                listOf(
                    NotificationChannel(
                        CHANNEL_AI_MATCH,
                        "AI 智慧配對",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "AI 成功配對相似物品時通知"
                        enableVibration(true)
                    },
                    NotificationChannel(
                        CHANNEL_MESSAGES,
                        "新訊息",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "收到新聊天訊息時通知"
                        enableVibration(true)
                    },
                    NotificationChannel(
                        CHANNEL_NEARBY,
                        "附近物品提醒",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "附近出現遺失物或撿到物時通知"
                    },
                    NotificationChannel(
                        CHANNEL_GENERAL,
                        "一般通知",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "系統一般通知"
                    }
                )
            )
        }
    }

    // ── 發送通知的共用方法 ──

    private fun sendNotification(
        context: Context,
        channelId: String,
        title: String,
        message: String,
        iconRes: Int = android.R.drawable.ic_dialog_info,
        deepLinkExtra: String? = null
    ) {
        if (!hasNotificationPermission(context)) return

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            deepLinkExtra?.let { putExtra("deep_link", it) }
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notifIdCounter,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(notifIdCounter++, notification)
    }

    // ── AI 配對通知 ──

    fun showAiMatchNotification(
        context: Context,
        matchedItemTitle: String,
        sourceItemTitle: String,
        matchedItemId: String? = null
    ) {
        sendNotification(
            context = context,
            channelId = CHANNEL_AI_MATCH,
            title = "🤖 AI 配對成功！",
            message = "您的「$sourceItemTitle」可能與「$matchedItemTitle」是同一件物品",
            deepLinkExtra = matchedItemId?.let { "foundit://item/$it" }
        )
    }

    // ── 新訊息通知 ──

    fun showMessageNotification(
        context: Context,
        senderName: String,
        messageContent: String,
        chatId: String? = null
    ) {
        sendNotification(
            context = context,
            channelId = CHANNEL_MESSAGES,
            title = "💬 $senderName 傳來訊息",
            message = messageContent,
            deepLinkExtra = chatId?.let { "foundit://chat/$it" }
        )
    }

    // ── 附近物品通知 ──

    fun showNearbyItemNotification(
        context: Context,
        itemTitle: String,
        locationName: String,
        itemId: String? = null
    ) {
        sendNotification(
            context = context,
            channelId = CHANNEL_NEARBY,
            title = "📍 附近發現物品",
            message = "在「$locationName」附近有人登記了「$itemTitle」",
            deepLinkExtra = itemId?.let { "foundit://item/$it" }
        )
    }

    // ── QR 掃描通知 ──

    fun showQrScannedNotification(
        context: Context,
        itemName: String
    ) {
        sendNotification(
            context = context,
            channelId = CHANNEL_GENERAL,
            title = "🔍 有人掃描了您的 QR Code",
            message = "有人掃描了您「$itemName」的防丟標籤，可能找到了您的物品！"
        )
    }

    // ── 一般系統通知 ──

    fun showGeneralNotification(
        context: Context,
        title: String,
        message: String
    ) {
        sendNotification(
            context = context,
            channelId = CHANNEL_GENERAL,
            title = title,
            message = message
        )
    }

    // ── 工具方法 ──

    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    fun openNotificationSettings(context: Context) {
        val intent = Intent().apply {
            action = android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
            putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        context.startActivity(intent)
    }
}
