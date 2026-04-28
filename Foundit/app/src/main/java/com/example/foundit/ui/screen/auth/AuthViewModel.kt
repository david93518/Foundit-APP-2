package com.example.foundit.ui.screen.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.User
import com.example.foundit.data.repository.AuthResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AuthUiState(
    val isLoading: Boolean = false,
    val isLoggedIn: Boolean = false,
    val user: User? = null,
    val errorMessage: String? = null,
    val otpSent: Boolean = false,
    val phone: String = ""
)

class AuthViewModel : ViewModel() {

    private val repository = FounditApplication.instance.authRepository

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        checkLoginStatus()
    }

    /** 啟動時確認是否已登入 */
    fun checkLoginStatus() {
        viewModelScope.launch {
            val loggedIn = repository.isLoggedIn()
            if (loggedIn) {
                repository.getMe().let { result ->
                    when (result) {
                        is AuthResult.Success -> _uiState.value = _uiState.value.copy(
                            isLoggedIn = true,
                            user = result.data
                        )
                        is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                            isLoggedIn = true
                        )
                    }
                }
            }
        }
    }

    /** 發送 OTP 驗證碼 */
    fun sendOtp(phone: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null, phone = phone)
            when (val result = repository.sendOtp(phone)) {
                is AuthResult.Success -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    otpSent = true
                )
                is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 驗證 OTP 並登入 */
    fun verifyOtp(phone: String, otp: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = repository.verifyOtp(phone, otp)) {
                is AuthResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        user = result.data
                    )
                    onSuccess()
                }
                is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** Google / LINE OAuth 登入 */
    fun oauthLogin(
        provider: String,
        token: String,
        name: String? = null,
        avatarUrl: String? = null,
        onSuccess: () -> Unit
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = repository.oauthLogin(provider, token, name, avatarUrl)) {
                is AuthResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        user = result.data
                    )
                    onSuccess()
                }
                is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 登出 */
    fun logout(onSuccess: () -> Unit) {
        viewModelScope.launch {
            repository.logout()
            _uiState.value = AuthUiState()
            onSuccess()
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    /** 設定錯誤訊息（例如 Google 登入設定未完成） */
    fun setExternalError(message: String) {
        _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = message)
    }
}
