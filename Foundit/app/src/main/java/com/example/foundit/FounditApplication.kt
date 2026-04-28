package com.example.foundit

import android.app.Application
import com.example.foundit.data.local.AppPreferences
import com.example.foundit.data.remote.MockApiService
import com.example.foundit.data.remote.RetrofitClient
import com.example.foundit.data.repository.AuthRepository
import com.example.foundit.data.repository.ChatRepository
import com.example.foundit.data.repository.ItemRepository
import com.example.foundit.util.Constants
import com.example.foundit.util.NotificationHelper

/**
 * Application 類別，使用 ServiceLocator 模式管理依賴。
 * 當 Constants.USE_MOCK = true 時注入 MockApiService（後端未部署時使用）；
 * 後端部署完成後將 USE_MOCK 改為 false 即可切換至真實 API。
 */
class FounditApplication : Application() {

    val preferences by lazy { AppPreferences(this) }
    val apiService by lazy {
        if (Constants.USE_MOCK) MockApiService() else RetrofitClient.create(preferences)
    }
    val authRepository by lazy { AuthRepository(apiService, preferences) }
    val itemRepository by lazy { ItemRepository(apiService) }
    val chatRepository by lazy { ChatRepository(apiService) }

    companion object {
        lateinit var instance: FounditApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        NotificationHelper.createNotificationChannels(this)
    }
}
