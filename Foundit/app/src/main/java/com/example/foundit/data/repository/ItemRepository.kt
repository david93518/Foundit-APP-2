package com.example.foundit.data.repository

import com.example.foundit.data.model.AiMatchResult
import com.example.foundit.data.model.Item
import com.example.foundit.data.model.ItemRequest
import com.example.foundit.data.remote.AiMatchRequest
import com.example.foundit.data.remote.ApiService
import com.example.foundit.data.remote.ItemFilter
import com.example.foundit.util.Constants
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
}

class ItemRepository(private val api: ApiService) {

    /** 取得物品列表（支援篩選條件）*/
    suspend fun getItems(filter: ItemFilter = ItemFilter()): Result<List<Item>> {
        return try {
            val response = api.getItems(filter.toQueryMap())
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("載入物品失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 取得單一物品詳情 */
    suspend fun getItem(id: String): Result<Item> {
        return try {
            val response = api.getItem(id)
            val item = response.body()?.data
            if (response.isSuccessful && item != null) {
                Result.Success(item)
            } else {
                Result.Error("找不到此物品")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 建立新物品 */
    suspend fun createItem(request: ItemRequest): Result<Item> {
        return try {
            val response = api.createItem(request)
            val item = response.body()?.data
            if (response.isSuccessful && item != null) {
                Result.Success(item)
            } else {
                Result.Error("發布失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 更新物品 */
    suspend fun updateItem(id: String, request: ItemRequest): Result<Item> {
        return try {
            val response = api.updateItem(id, request)
            val item = response.body()?.data
            if (response.isSuccessful && item != null) {
                Result.Success(item)
            } else {
                Result.Error("更新失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 刪除物品 */
    suspend fun deleteItem(id: String): Result<Unit> {
        return try {
            val response = api.deleteItem(id)
            if (response.isSuccessful) {
                Result.Success(Unit)
            } else {
                Result.Error("刪除失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 標記物品已找到/已解決 */
    suspend fun resolveItem(id: String): Result<Unit> {
        return try {
            val response = api.resolveItem(id)
            if (response.isSuccessful) {
                Result.Success(Unit)
            } else {
                Result.Error("操作失敗")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** AI 配對 */
    suspend fun aiMatch(itemId: String? = null, imageUrl: String? = null): Result<List<AiMatchResult>> {
        return try {
            val response = api.aiMatch(AiMatchRequest(itemId, imageUrl))
            if (response.isSuccessful) {
                Result.Success(response.body()?.data ?: emptyList())
            } else {
                Result.Error("AI 配對失敗，請稍後再試")
            }
        } catch (e: Exception) {
            Result.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 上傳單張圖片，回傳可給後端 items 使用的 URL（已將 localhost 替換為裝置可連的 API 主機） */
    suspend fun uploadImage(bytes: ByteArray, fileName: String, mimeType: String): Result<String> {
        return try {
            val body = bytes.toRequestBody(mimeType.toMediaTypeOrNull())
            val part = MultipartBody.Part.createFormData("file", fileName, body)
            val response = api.uploadImage(part)
            val url = response.body()?.url.orEmpty()
            if (response.isSuccessful && url.isNotBlank()) {
                Result.Success(rewriteUploadUrlForDevice(url))
            } else {
                Result.Error(response.body()?.let { if (!it.success) "上傳失敗" else "未取得圖片網址" }
                    ?: "上傳失敗")
            }
        } catch (e: Exception) {
            Result.Error("圖片上傳失敗：${e.localizedMessage}")
        }
    }

    private fun rewriteUploadUrlForDevice(url: String): String {
        val origin = Constants.API_ORIGIN
        return url
            .replace("http://localhost:3000", origin)
            .replace("http://127.0.0.1:3000", origin)
    }
}
