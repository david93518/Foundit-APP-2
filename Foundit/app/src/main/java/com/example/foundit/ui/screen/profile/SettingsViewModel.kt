package com.example.foundit.ui.screen.profile

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private val Context.settingsDataStore: DataStore<Preferences>
    by preferencesDataStore(name = "foundit_settings")

data class SettingsUiState(
    val isDarkMode: Boolean = false,
    val aiMatchNotif: Boolean = true,
    val messageNotif: Boolean = true,
    val nearbyNotif: Boolean = true,
    val qrScanNotif: Boolean = true,
    val showVersion: Boolean = false
)

class SettingsViewModel : ViewModel() {

    private val context = FounditApplication.instance

    private object Keys {
        val DARK_MODE = booleanPreferencesKey("dark_mode")
        val AI_MATCH_NOTIF = booleanPreferencesKey("notif_ai_match")
        val MESSAGE_NOTIF = booleanPreferencesKey("notif_message")
        val NEARBY_NOTIF = booleanPreferencesKey("notif_nearby")
        val QR_SCAN_NOTIF = booleanPreferencesKey("notif_qr_scan")
    }

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadSettings()
    }

    private fun loadSettings() {
        viewModelScope.launch {
            context.settingsDataStore.data.collect { prefs ->
                _uiState.value = SettingsUiState(
                    isDarkMode = prefs[Keys.DARK_MODE] ?: false,
                    aiMatchNotif = prefs[Keys.AI_MATCH_NOTIF] ?: true,
                    messageNotif = prefs[Keys.MESSAGE_NOTIF] ?: true,
                    nearbyNotif = prefs[Keys.NEARBY_NOTIF] ?: true,
                    qrScanNotif = prefs[Keys.QR_SCAN_NOTIF] ?: true
                )
            }
        }
    }

    fun toggleDarkMode() {
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[Keys.DARK_MODE] = !(_uiState.value.isDarkMode)
            }
        }
    }

    fun toggleAiMatchNotif() {
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[Keys.AI_MATCH_NOTIF] = !(_uiState.value.aiMatchNotif)
            }
        }
    }

    fun toggleMessageNotif() {
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[Keys.MESSAGE_NOTIF] = !(_uiState.value.messageNotif)
            }
        }
    }

    fun toggleNearbyNotif() {
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[Keys.NEARBY_NOTIF] = !(_uiState.value.nearbyNotif)
            }
        }
    }

    fun toggleQrScanNotif() {
        viewModelScope.launch {
            context.settingsDataStore.edit { prefs ->
                prefs[Keys.QR_SCAN_NOTIF] = !(_uiState.value.qrScanNotif)
            }
        }
    }
}
