package com.example.foundit.data.remote

import com.example.foundit.data.local.AppPreferences
import com.example.foundit.util.Constants
import com.google.gson.GsonBuilder
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object RetrofitClient {

    fun create(preferences: AppPreferences): ApiService {
        // Kotlin 非 null Long 欄位編譯為 JVM primitive long；僅註冊 javaObjectType 時 ISO 日期字串仍會走預設解析而拋 NumberFormatException
        val gson = GsonBuilder()
            .setLenient()
            .registerTypeAdapter(Long::class.javaObjectType, GsonLongTypeAdapter)
            .registerTypeAdapter(Long::class.javaPrimitiveType!!, GsonLongTypeAdapter)
            .registerTypeAdapter(
                com.example.foundit.data.model.Message::class.java,
                MessageDeserializer
            )
            .create()

        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }

        // 自動帶入 Auth Token 的 Interceptor
        val authInterceptor = Interceptor { chain ->
            val token = runBlocking { preferences.authToken.first() }
            val request = chain.request().newBuilder().apply {
                if (!token.isNullOrBlank()) {
                    addHeader("Authorization", "Bearer $token")
                }
                addHeader("Accept", "application/json")
            }.build()
            chain.proceed(request)
        }

        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        return Retrofit.Builder()
            .baseUrl(Constants.BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
            .create(ApiService::class.java)
    }
}
