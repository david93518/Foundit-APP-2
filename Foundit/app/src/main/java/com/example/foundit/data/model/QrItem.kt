package com.example.foundit.data.model

import com.google.gson.annotations.SerializedName

data class QrItem(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("user_id")
    val userId: String = "",

    @SerializedName("name")
    val name: String = "",

    @SerializedName("description")
    val description: String = "",

    /** QR Code 內容（URL 或 UUID）*/
    @SerializedName("qr_code")
    val qrCode: String = "",

    /** QR Code 圖片 URL（後端產生）*/
    @SerializedName("qr_image_url")
    val qrImageUrl: String = "",

    @SerializedName("created_at")
    val createdAt: Long = System.currentTimeMillis()
)

data class GenerateQrRequest(
    @SerializedName("name")
    val name: String,

    @SerializedName("description")
    val description: String = ""
)

data class AiMatchResult(
    @SerializedName("item")
    val item: Item,

    @SerializedName("score")
    val score: Float = 0f
) {
    val similarityPercent: Int get() = (score * 100).toInt()
}
