package com.example.foundit.ui.screen.profile

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.User
import com.example.foundit.data.repository.AuthResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ProfileUiState(
    val isLoading: Boolean = false,
    val user: User? = null,
    val errorMessage: String? = null,
    val updateSuccess: Boolean = false,
    val avatarUri: Uri? = null
)

class ProfileViewModel : ViewModel() {

    private val authRepository = FounditApplication.instance.authRepository

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadCurrentUser()
    }

    fun loadCurrentUser() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            when (val result = authRepository.getMe()) {
                is AuthResult.Success<User> -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    user = result.data
                )
                is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    fun setAvatarUri(uri: Uri?) {
        _uiState.value = _uiState.value.copy(avatarUri = uri)
    }

    fun updateProfile(name: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = authRepository.updateProfile(
                name = name,
                avatarUrl = _uiState.value.avatarUri?.toString() ?: ""
            )) {
                is AuthResult.Success<User> -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    updateSuccess = true,
                    user = result.data
                )
                is AuthResult.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    fun clearUpdateSuccess() {
        _uiState.value = _uiState.value.copy(updateSuccess = false, errorMessage = null)
    }
}
