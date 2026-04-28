package com.example.foundit.data.remote

import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import java.lang.reflect.Type
import java.time.Instant

/**
 * NestJS / TypeORM 常回傳 ISO-8601 字串；App 模型使用 Long 毫秒。
 * 同時支援數字毫秒與字串數字。
 */
object GsonLongTypeAdapter : JsonDeserializer<Long>, JsonSerializer<Long> {
    override fun deserialize(
        json: JsonElement?,
        typeOfT: Type?,
        context: JsonDeserializationContext?
    ): Long {
        if (json == null || json.isJsonNull) return 0L
        val p = json.asJsonPrimitive
        return when {
            p.isNumber -> p.asLong
            p.isString -> {
                val s = p.asString
                s.toLongOrNull()
                    ?: runCatching { Instant.parse(s).toEpochMilli() }.getOrDefault(0L)
            }
            else -> 0L
        }
    }

    override fun serialize(
        src: Long?,
        typeOfSrc: Type?,
        context: JsonSerializationContext?
    ): JsonElement = JsonPrimitive(src ?: 0L)
}
