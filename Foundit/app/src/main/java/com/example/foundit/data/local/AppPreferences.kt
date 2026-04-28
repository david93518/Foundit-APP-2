package com.example.foundit.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.foundit.util.Constants
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "foundit_prefs")

class AppPreferences(private val context: Context) {

    private object Keys {
        val AUTH_TOKEN = stringPreferencesKey(Constants.PREF_AUTH_TOKEN)
        val USER_ID = stringPreferencesKey(Constants.PREF_USER_ID)
        val USER_NAME = stringPreferencesKey(Constants.PREF_USER_NAME)
        val USER_AVATAR = stringPreferencesKey(Constants.PREF_USER_AVATAR)
        val USER_PHONE = stringPreferencesKey(Constants.PREF_USER_PHONE)
        val IS_LOGGED_IN = booleanPreferencesKey(Constants.PREF_IS_LOGGED_IN)
        val ONBOARDING_DONE = booleanPreferencesKey(Constants.PREF_ONBOARDING_DONE)
    }

    // ── 讀取 ──

    val authToken: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.AUTH_TOKEN]
    }

    val userId: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.USER_ID]
    }

    val userName: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.USER_NAME]
    }

    val userAvatar: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.USER_AVATAR]
    }

    val userPhone: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.USER_PHONE]
    }

    val isLoggedIn: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[Keys.IS_LOGGED_IN] ?: false
    }

    val isOnboardingDone: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[Keys.ONBOARDING_DONE] ?: false
    }

    // ── 寫入 ──

    suspend fun saveAuthInfo(token: String, userId: String, userName: String, phone: String) {
        context.dataStore.edit { prefs ->
            prefs[Keys.AUTH_TOKEN] = token
            prefs[Keys.USER_ID] = userId
            prefs[Keys.USER_NAME] = userName
            prefs[Keys.USER_PHONE] = phone
            prefs[Keys.IS_LOGGED_IN] = true
        }
    }

    suspend fun saveUserAvatar(avatarUrl: String) {
        context.dataStore.edit { prefs ->
            prefs[Keys.USER_AVATAR] = avatarUrl
        }
    }

    suspend fun saveUserName(name: String) {
        context.dataStore.edit { prefs ->
            prefs[Keys.USER_NAME] = name
        }
    }

    suspend fun setOnboardingDone() {
        context.dataStore.edit { prefs ->
            prefs[Keys.ONBOARDING_DONE] = true
        }
    }

    suspend fun clearAll() {
        context.dataStore.edit { it.clear() }
    }
}
