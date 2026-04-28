package com.example.foundit.data.model

import com.google.gson.annotations.SerializedName

enum class ItemType(val label: String) {
    LOST("遺失物"),
    FOUND("撿到物")
}

enum class ItemStatus(val label: String) {
    ACTIVE("尋找中"),
    RESOLVED("已找到"),
    CLOSED("已關閉")
}

data class Item(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("type")
    val type: ItemType = ItemType.LOST,

    @SerializedName("user_id")
    val userId: String = "",

    @SerializedName("user_name")
    val userName: String = "",

    @SerializedName("user_avatar")
    val userAvatar: String = "",

    @SerializedName("title")
    val title: String = "",

    @SerializedName("category")
    val category: String = "",

    @SerializedName("description")
    val description: String = "",

    @SerializedName("color")
    val color: String = "",

    @SerializedName("images")
    val images: List<String> = emptyList(),

    @SerializedName("latitude")
    val latitude: Double = 0.0,

    @SerializedName("longitude")
    val longitude: Double = 0.0,

    @SerializedName("location_name")
    val locationName: String = "",

    /** 遺失/撿到時間 (Unix timestamp ms) */
    @SerializedName("lost_at")
    val lostAt: Long = System.currentTimeMillis(),

    @SerializedName("reward")
    val reward: Int = 0,

    @SerializedName("has_reward")
    val hasReward: Boolean = false,

    @SerializedName("storage_location")
    val storageLocation: String = "",

    @SerializedName("handed_to_police")
    val handedToPolice: Boolean = false,

    @SerializedName("status")
    val status: ItemStatus = ItemStatus.ACTIVE,

    @SerializedName("created_at")
    val createdAt: Long = System.currentTimeMillis(),

    @SerializedName("updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)

/** 用於建立/編輯物品的請求物件（與 Nest CreateItemDto camelCase 一致） */
data class ItemRequest(
    @SerializedName("type")
    val type: String,

    @SerializedName("title")
    val title: String,

    @SerializedName("category")
    val category: String,

    @SerializedName("description")
    val description: String,

    @SerializedName("color")
    val color: String,

    @SerializedName("images")
    val images: List<String> = emptyList(),

    @SerializedName("latitude")
    val latitude: Double,

    @SerializedName("longitude")
    val longitude: Double,

    @SerializedName("locationName")
    val locationName: String,

    @SerializedName("lostAt")
    val lostAt: Long,

    @SerializedName("reward")
    val reward: Int = 0,

    @SerializedName("hasReward")
    val hasReward: Boolean = false,

    @SerializedName("storageLocation")
    val storageLocation: String = "",

    @SerializedName("handedToPolice")
    val handedToPolice: Boolean = false
)
