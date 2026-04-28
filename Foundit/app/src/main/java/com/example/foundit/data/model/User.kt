package com.example.foundit.data.model

import com.google.gson.annotations.SerializedName

data class User(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("phone")
    val phone: String = "",

    @SerializedName("name")
    val name: String = "",

    /** Nest 實體欄位為 camelCase */
    @SerializedName("avatarUrl")
    val avatarUrl: String = "",

    @SerializedName("createdAt")
    val createdAt: Long = System.currentTimeMillis(),

    @SerializedName("points")
    val points: Int = 0,

    @SerializedName("isVerified")
    val isVerified: Boolean = false
)
