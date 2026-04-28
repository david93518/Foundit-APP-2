package com.example.foundit.data.repository

import com.example.foundit.data.model.Chat
import com.example.foundit.data.model.CreateChatRequest
import com.example.foundit.data.model.GenerateQrRequest
import com.example.foundit.data.model.Message
import com.example.foundit.data.model.Notification
import com.example.foundit.data.model.QrItem
import com.example.foundit.data.remote.QrScanResponse
import com.example.foundit.data.model.SendMessageRequest
import com.example.foundit.data.remote.ApiService

class ChatRepository(private val api: ApiService) {

    // ── 聊天 ──

    /** 建立聊天室（對應某物品）*/
    suspend fun createOrGetChat(itemId: String): Result<Chat> {
        return try {
            val response = api.createChat(CreateChatRequest(itemId))
            val chat = response.body()?.data
            if (response.isSuccessful && chat != null) {
                Result.Success(chat)
            } else {
                Result.Error("無法建立聊天室")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 取得所有聊天列表 */
    suspend fun getChats(): Result<List<Chat>> {
        return try {
            val response = api.getChats()
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("載入聊天列表失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 取得聊天室訊息 */
    suspend fun getMessages(chatId: String, page: Int = 1): Result<List<Message>> {
        return try {
            val response = api.getMessages(chatId, page)
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("載入訊息失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 發送訊息 */
    suspend fun sendMessage(chatId: String, content: String): Result<Message> {
        return try {
            val response = api.sendMessage(chatId, SendMessageRequest(content))
            val message = response.body()?.data
            if (response.isSuccessful && message != null) {
                Result.Success(message)
            } else {
                Result.Error("發送失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    // ── QR Code ──

    /** 產生 QR Code */
    suspend fun generateQr(name: String, description: String = ""): Result<QrItem> {
        return try {
            val response = api.generateQr(GenerateQrRequest(name, description))
            val qrItem = response.body()?.data
            if (response.isSuccessful && qrItem != null) {
                Result.Success(qrItem)
            } else {
                Result.Error("產生 QR Code 失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 取得我的 QR 物品列表 */
    suspend fun getQrItems(): Result<List<QrItem>> {
        return try {
            val response = api.getQrItems()
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("載入 QR 物品失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 刪除 QR 物品 */
    suspend fun deleteQrItem(id: String): Result<Unit> {
        return try {
            val response = api.deleteQrItem(id)
            if (response.isSuccessful) Result.Success(Unit)
            else Result.Error("刪除失敗")
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 掃描 QR 內容（後端辨識 code） */
    suspend fun scanQrCode(code: String): Result<QrScanResponse> {
        return try {
            val response = api.scanQr(code)
            val body = response.body()
            if (response.isSuccessful && body != null) {
                Result.Success(body)
            } else {
                Result.Error("查無此 QR 或已失效")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    // ── 通知 ──

    /** 取得通知列表 */
    suspend fun getNotifications(): Result<List<Notification>> {
        return try {
            val response = api.getNotifications()
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("載入通知失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 標記通知已讀 */
    suspend fun markNotificationRead(id: String): Result<Unit> {
        return try {
            val response = api.markNotificationRead(id)
            if (response.isSuccessful) Result.Success(Unit)
            else Result.Error("操作失敗")
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 全部通知標記已讀 */
    suspend fun markAllNotificationsRead(): Result<Unit> {
        return try {
            val response = api.markAllNotificationsRead()
            if (response.isSuccessful) Result.Success(Unit)
            else Result.Error("操作失敗")
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }
}
