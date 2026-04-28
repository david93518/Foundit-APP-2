package com.example.foundit.data.repository

import com.example.foundit.data.local.AppPreferences
import com.example.foundit.data.model.User
import com.example.foundit.data.remote.ApiService
import com.example.foundit.data.remote.OAuthRequest
import com.example.foundit.data.remote.SendOtpRequest
import com.example.foundit.data.remote.UpdateProfileRequest
import com.example.foundit.data.remote.VerifyOtpRequest
import kotlinx.coroutines.flow.first

sealed class AuthResult<out T> {
    data class Success<T>(val data: T) : AuthResult<T>()
    data class Error(val message: String) : AuthResult<Nothing>()
}

class AuthRepository(
    private val api: ApiService,
    private val preferences: AppPreferences
) {

    /** 發送手機 OTP 驗證碼 */
    suspend fun sendOtp(phone: String): AuthResult<Unit> {
        return try {
            val response = api.sendOtp(SendOtpRequest(phone))
            if (response.isSuccessful && response.body()?.success == true) {
                AuthResult.Success(Unit)
            } else {
                AuthResult.Error(response.body()?.message ?: "發送驗證碼失敗")
            }
        } catch (e: Exception) {
            AuthResult.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 驗證 OTP 並登入 */
    suspend fun verifyOtp(phone: String, otp: String): AuthResult<User> {
        return try {
            val response = api.verifyOtp(VerifyOtpRequest(phone, otp))
            val body = response.body()
            if (response.isSuccessful && body?.success == true && body.user != null) {
                val user = body.user
                preferences.saveAuthInfo(
                    token = body.token,
                    userId = user.id,
                    userName = user.name,
                    phone = user.phone
                )
                AuthResult.Success(user)
            } else {
                AuthResult.Error(body?.message ?: "驗證碼錯誤")
            }
        } catch (e: Exception) {
            AuthResult.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** Google / LINE OAuth 登入（Google 請傳 idToken；可選名稱與頭像網址） */
    suspend fun oauthLogin(
        provider: String,
        token: String,
        name: String? = null,
        avatarUrl: String? = null
    ): AuthResult<User> {
        return try {
            val response = api.oauthLogin(
                provider,
                OAuthRequest(token, provider, name, avatarUrl)
            )
            val body = response.body()
            if (response.isSuccessful && body?.success == true && body.user != null) {
                val user = body.user
                preferences.saveAuthInfo(
                    token = body.token,
                    userId = user.id,
                    userName = user.name,
                    phone = user.phone
                )
                AuthResult.Success(user)
            } else {
                AuthResult.Error(body?.message ?: "第三方登入失敗")
            }
        } catch (e: Exception) {
            AuthResult.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 取得目前使用者資料 */
    suspend fun getMe(): AuthResult<User> {
        return try {
            val response = api.getMe()
            val user = response.body()?.data
            if (response.isSuccessful && user != null) {
                preferences.saveUserName(user.name)
                user.avatarUrl.takeIf { it.isNotBlank() }?.let {
                    preferences.saveUserAvatar(it)
                }
                AuthResult.Success(user)
            } else {
                AuthResult.Error("無法取得使用者資料")
            }
        } catch (e: Exception) {
            AuthResult.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 更新個人資料 */
    suspend fun updateProfile(name: String, avatarUrl: String): AuthResult<User> {
        return try {
            val response = api.updateProfile(UpdateProfileRequest(name, avatarUrl))
            val user = response.body()?.data
            if (response.isSuccessful && user != null) {
                preferences.saveUserName(user.name)
                if (user.avatarUrl.isNotBlank()) preferences.saveUserAvatar(user.avatarUrl)
                AuthResult.Success(user)
            } else {
                AuthResult.Error("更新失敗")
            }
        } catch (e: Exception) {
            AuthResult.Error("網路連線失敗：${e.localizedMessage}")
        }
    }

    /** 確認是否已登入 */
    suspend fun isLoggedIn(): Boolean = preferences.isLoggedIn.first()

    /** 登出（清除本地資料）*/
    suspend fun logout() {
        preferences.clearAll()
    }
}
