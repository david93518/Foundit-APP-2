package com.example.foundit.util

import com.example.foundit.BuildConfig
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class GeocodeHit(val latLng: LatLng, val formattedAddress: String)

/**
 * 以 Google Geocoding API 將地址／地標文字轉成座標（須在 GCP 啟用「Geocoding API」，金鑰與 Maps SDK 相同）。
 */
object GeocodingClient {

    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    suspend fun geocodeAddress(query: String): Result<GeocodeHit> = withContext(Dispatchers.IO) {
        val key = BuildConfig.MAPS_API_KEY.trim()
        if (key.isEmpty() || key == "YOUR_GOOGLE_MAPS_API_KEY") {
            return@withContext Result.failure(IllegalStateException("尚未設定 MAPS_API_KEY（local.properties）"))
        }
        val trimmed = query.trim()
        if (trimmed.isEmpty()) {
            return@withContext Result.failure(IllegalArgumentException("請輸入地點名稱"))
        }
        runCatching {
            val url = "https://maps.googleapis.com/maps/api/geocode/json".toHttpUrl().newBuilder()
                .addQueryParameter("address", trimmed)
                .addQueryParameter("key", key)
                .addQueryParameter("language", "zh-TW")
                .addQueryParameter("region", "tw")
                .build()
            val request = Request.Builder().url(url).get().build()
            http.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) {
                    throw Exception("網路錯誤 (${resp.code})")
                }
                val body = resp.body?.string().orEmpty()
                val json = JSONObject(body)
                val status = json.optString("status", "")
                when (status) {
                    "OK" -> {
                        val r0 = json.getJSONArray("results").getJSONObject(0)
                        val loc = r0.getJSONObject("geometry").getJSONObject("location")
                        val lat = loc.getDouble("lat")
                        val lng = loc.getDouble("lng")
                        val formatted = r0.optString("formatted_address", trimmed)
                        GeocodeHit(LatLng(lat, lng), formatted)
                    }
                    "ZERO_RESULTS" -> throw Exception("找不到「$trimmed」對應的位置，請換個說法試試")
                    "REQUEST_DENIED" -> throw Exception(
                        "Geocoding API 被拒絕：請在 Google Cloud Console 啟用「Geocoding API」，並確認金鑰限制允許此 API",
                    )
                    "OVER_QUERY_LIMIT" -> throw Exception("查詢次數過多，請稍後再試")
                    else -> throw Exception("無法查詢地點：$status")
                }
            }
        }.fold(
            onSuccess = { Result.success(it) },
            onFailure = { Result.failure(it as? Exception ?: Exception(it.message)) },
        )
    }
}
