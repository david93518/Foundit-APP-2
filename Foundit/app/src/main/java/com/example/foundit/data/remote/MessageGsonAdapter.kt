package com.example.foundit.data.remote

import com.example.foundit.data.model.Message
import com.example.foundit.data.model.MessageType
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import java.lang.reflect.Type
import java.time.Instant
import java.time.format.DateTimeParseException
/** 後端訊息 JSON 可能含巢狀 sender、ISO 時間字串，由此統一解析 */
object MessageDeserializer : JsonDeserializer<Message> {
    override fun deserialize(json: JsonElement, typeOfT: Type, context: JsonDeserializationContext): Message {
        val o = json.asJsonObject
        fun str(key: String): String = o.get(key)?.takeIf { !it.isJsonNull }?.asString ?: ""

        fun parseLongMs(key: String): Long {
            val e = o.get(key) ?: return 0L
            if (e.isJsonNull) return 0L
            return when {
                e.isJsonPrimitive && e.asJsonPrimitive.isNumber -> e.asLong
                e.isJsonPrimitive && e.asJsonPrimitive.isString -> parseIsoMillis(e.asString)
                else -> 0L
            }
        }

        fun parseReadAt(): Long? {
            val e = o.get("readAt") ?: o.get("read_at") ?: return null
            if (e.isJsonNull) return null
            return when {
                e.isJsonPrimitive && e.asJsonPrimitive.isNumber -> e.asLong
                e.isJsonPrimitive && e.asJsonPrimitive.isString -> parseIsoMillis(e.asString).takeIf { it > 0 }
                else -> null
            }
        }

        val senderEl = o.get("sender")
        val sender = if (senderEl != null && senderEl.isJsonObject) senderEl.asJsonObject else null
        var senderId = str("senderId").ifBlank { str("sender_id") }
        var senderName = str("senderName").ifBlank { str("sender_name") }
        var senderAvatar = str("senderAvatar").ifBlank { str("sender_avatar") }
        if (sender != null) {
            if (senderId.isBlank()) senderId = sender.get("id")?.takeIf { !it.isJsonNull }?.asString ?: ""
            if (senderName.isBlank()) senderName = sender.get("name")?.takeIf { !it.isJsonNull }?.asString ?: ""
            if (senderAvatar.isBlank()) {
                senderAvatar = sender.get("avatarUrl")?.takeIf { !it.isJsonNull }?.asString
                    ?: sender.get("avatar_url")?.takeIf { !it.isJsonNull }?.asString ?: ""
            }
        }

        val typeStr = str("type").uppercase()
        val type = runCatching { MessageType.valueOf(typeStr) }.getOrDefault(MessageType.TEXT)

        val readAtVal = parseReadAt()
        val created = parseLongMs("createdAt").takeIf { it > 0 }
            ?: parseLongMs("created_at")
            ?: System.currentTimeMillis()

        return Message(
            id = str("id"),
            chatId = str("chatId").ifBlank { str("chat_id") },
            senderId = senderId,
            senderName = senderName,
            senderAvatar = senderAvatar,
            content = str("content"),
            type = type,
            readAt = readAtVal,
            createdAt = created
        )
    }

    private fun parseIsoMillis(s: String): Long {
        if (s.isBlank()) return 0L
        return try {
            Instant.parse(s).toEpochMilli()
        } catch (_: DateTimeParseException) {
            0L
        }
    }
}
