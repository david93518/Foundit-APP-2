package com.example.foundit.data.model

import com.google.gson.annotations.SerializedName

/** 後端 chats 關聯的 User 物件（與 Nest/TypeORM 回傳一致） */
data class ChatParticipant(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("name")
    val name: String = "",
    @SerializedName("phone")
    val phone: String = "",
    @SerializedName(value = "avatar_url", alternate = ["avatarUrl"])
    val avatarUrl: String = ""
)

data class Chat(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("item_id")
    val itemId: String = "",

    @SerializedName("item_title")
    val itemTitle: String = "",

    @SerializedName("item_image")
    val itemImage: String = "",

    @SerializedName("participants")
    val participants: List<ChatParticipant> = emptyList(),

    @SerializedName("other_user_name")
    val otherUserName: String = "",

    @SerializedName("other_user_avatar")
    val otherUserAvatar: String = "",

    @SerializedName("last_message")
    val lastMessage: String = "",

    @SerializedName("last_message_at")
    val lastMessageAt: Long = 0L,

    @SerializedName("unread_count")
    val unreadCount: Int = 0
)

enum class MessageType { TEXT, IMAGE, LOCATION, SYSTEM }

data class Message(
    @SerializedName("id")
    val id: String = "",

    @SerializedName("chat_id")
    val chatId: String = "",

    @SerializedName("sender_id")
    val senderId: String = "",

    @SerializedName("sender_name")
    val senderName: String = "",

    @SerializedName("sender_avatar")
    val senderAvatar: String = "",

    @SerializedName("content")
    val content: String = "",

    @SerializedName("type")
    val type: MessageType = MessageType.TEXT,

    @SerializedName("read_at")
    val readAt: Long? = null,

    @SerializedName("created_at")
    val createdAt: Long = System.currentTimeMillis()
) {
    val isRead: Boolean get() = readAt != null
}

data class SendMessageRequest(
    @SerializedName("content")
    val content: String
)

data class CreateChatRequest(
    @SerializedName("item_id")
    val itemId: String
)
