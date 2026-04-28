package com.example.foundit.data.remote

import com.example.foundit.data.model.AiMatchResult
import com.example.foundit.data.model.Chat
import com.example.foundit.data.model.CreateChatRequest
import com.example.foundit.data.model.GenerateQrRequest
import com.example.foundit.data.model.Item
import com.example.foundit.data.model.ItemRequest
import com.example.foundit.data.model.Message
import com.example.foundit.data.model.Notification
import com.example.foundit.data.model.QrItem
import com.example.foundit.data.model.SendMessageRequest
import com.example.foundit.data.model.User
import com.google.gson.annotations.SerializedName
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.QueryMap

// ── 通用回應包裝 ──

data class BaseResponse(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("message") val message: String = ""
)

data class DataResponse<T>(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("message") val message: String = "",
    @SerializedName("data") val data: T? = null
)

data class PagedResponse<T>(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("data") val data: List<T> = emptyList(),
    @SerializedName("total") val total: Int = 0,
    @SerializedName("page") val page: Int = 1,
    @SerializedName("has_more") val hasMore: Boolean = false
)

// ── Auth DTOs ──

data class SendOtpRequest(
    @SerializedName("phone") val phone: String
)

data class VerifyOtpRequest(
    @SerializedName("phone") val phone: String,
    @SerializedName("otp") val otp: String
)

data class AuthResponse(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("token") val token: String = "",
    @SerializedName("user") val user: User? = null,
    @SerializedName("message") val message: String = ""
)

data class OAuthRequest(
    @SerializedName("token") val token: String,
    @SerializedName("provider") val provider: String,
    @SerializedName("name") val name: String? = null,
    /** NestJS DTO 使用 camelCase；若後端改為 snake_case 請改為 avatar_url */
    @SerializedName("avatarUrl") val avatarUrl: String? = null
)

// ── User DTOs ──

data class UpdateProfileRequest(
    @SerializedName("name") val name: String,
    @SerializedName("avatar_url") val avatarUrl: String = ""
)

data class PointsResponse(
    @SerializedName("points") val points: Int = 0,
    @SerializedName("history") val history: List<PointEvent> = emptyList()
)

data class PointEvent(
    @SerializedName("type") val type: String = "",
    @SerializedName("points") val points: Int = 0,
    @SerializedName("description") val description: String = "",
    @SerializedName("created_at") val createdAt: Long = 0L
)

// ── Item DTOs ──

data class ItemFilter(
    val type: String? = null,
    val category: String? = null,
    val area: String? = null,
    val keyword: String? = null,
    val hasReward: Boolean? = null,
    val dateFrom: Long? = null,
    val dateTo: Long? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val radius: Double? = null,
    val page: Int = 1,
    val pageSize: Int = 20
) {
    fun toQueryMap(): Map<String, String> {
        val map = mutableMapOf<String, String>()
        type?.let { map["type"] = it }
        category?.let { map["category"] = it }
        area?.let { map["area"] = it }
        keyword?.let { map["keyword"] = it }
        hasReward?.let { map["has_reward"] = it.toString() }
        dateFrom?.let { map["date_from"] = it.toString() }
        dateTo?.let { map["date_to"] = it.toString() }
        lat?.let { map["lat"] = it.toString() }
        lng?.let { map["lng"] = it.toString() }
        radius?.let { map["radius"] = it.toString() }
        map["page"] = page.toString()
        map["page_size"] = pageSize.toString()
        return map
    }
}

// ── AI Match DTOs ──

data class AiMatchRequest(
    @SerializedName("item_id") val itemId: String? = null,
    @SerializedName("image_url") val imageUrl: String? = null
)

// ── QR DTOs ──

data class QrScanResponse(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("qr_item") val qrItem: QrItem? = null,
    @SerializedName("owner") val owner: User? = null
)

data class UploadImageResponse(
    @SerializedName("success") val success: Boolean = false,
    @SerializedName("url") val url: String = ""
)

// ── API Service Interface ──

interface ApiService {

    // ── 認證 ──

    @POST("auth/send-otp")
    suspend fun sendOtp(@Body request: SendOtpRequest): Response<BaseResponse>

    @POST("auth/verify-otp")
    suspend fun verifyOtp(@Body request: VerifyOtpRequest): Response<AuthResponse>

    @POST("auth/oauth/{provider}")
    suspend fun oauthLogin(
        @Path("provider") provider: String,
        @Body request: OAuthRequest
    ): Response<AuthResponse>

    // ── 使用者 ──

    @GET("users/me")
    suspend fun getMe(): Response<DataResponse<User>>

    @PATCH("users/me")
    suspend fun updateProfile(@Body request: UpdateProfileRequest): Response<DataResponse<User>>

    @GET("users/me/points")
    suspend fun getPoints(): Response<PointsResponse>

    // ── 物品 ──

    @GET("items")
    suspend fun getItems(@QueryMap filters: Map<String, String>): Response<PagedResponse<Item>>

    @POST("items")
    suspend fun createItem(@Body item: ItemRequest): Response<DataResponse<Item>>

    @GET("items/{id}")
    suspend fun getItem(@Path("id") id: String): Response<DataResponse<Item>>

    @PATCH("items/{id}")
    suspend fun updateItem(
        @Path("id") id: String,
        @Body item: ItemRequest
    ): Response<DataResponse<Item>>

    @DELETE("items/{id}")
    suspend fun deleteItem(@Path("id") id: String): Response<BaseResponse>

    @PATCH("items/{id}/resolve")
    suspend fun resolveItem(@Path("id") id: String): Response<BaseResponse>

    // ── 檔案上傳 ──

    @Multipart
    @POST("upload/image")
    suspend fun uploadImage(@Part file: MultipartBody.Part): Response<UploadImageResponse>

    // ── AI 配對 ──

    @POST("ai/match")
    suspend fun aiMatch(@Body request: AiMatchRequest): Response<DataResponse<List<AiMatchResult>>>

    // ── 聊天 ──

    @POST("chats")
    suspend fun createChat(@Body request: CreateChatRequest): Response<DataResponse<Chat>>

    @GET("chats")
    suspend fun getChats(): Response<DataResponse<List<Chat>>>

    @GET("chats/{id}/messages")
    suspend fun getMessages(
        @Path("id") chatId: String,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 50
    ): Response<PagedResponse<Message>>

    @POST("chats/{id}/messages")
    suspend fun sendMessage(
        @Path("id") chatId: String,
        @Body message: SendMessageRequest
    ): Response<DataResponse<Message>>

    // ── QR Code ──

    @POST("qr/generate")
    suspend fun generateQr(@Body request: GenerateQrRequest): Response<DataResponse<QrItem>>

    @GET("qr/items")
    suspend fun getQrItems(): Response<DataResponse<List<QrItem>>>

    @DELETE("qr/items/{id}")
    suspend fun deleteQrItem(@Path("id") id: String): Response<BaseResponse>

    @GET("qr/scan/{code}")
    suspend fun scanQr(@Path("code") code: String): Response<QrScanResponse>

    // ── 通知 ──

    @GET("notifications")
    suspend fun getNotifications(): Response<DataResponse<List<Notification>>>

    @PATCH("notifications/{id}/read")
    suspend fun markNotificationRead(@Path("id") id: String): Response<BaseResponse>

    @PATCH("notifications/read-all")
    suspend fun markAllNotificationsRead(): Response<BaseResponse>
}
