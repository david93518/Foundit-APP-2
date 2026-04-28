package com.example.foundit.ui.screen.qr

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.QrItem
import com.example.foundit.data.repository.Result
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class QrUiState(
    val isLoading: Boolean = false,
    val qrItems: List<QrItem> = emptyList(),
    val generatedQr: QrItem? = null,
    val errorMessage: String? = null,
    val isGenerating: Boolean = false,
    /** 掃描成功後顯示的聯絡資訊 */
    val scanResultMessage: String? = null
)

class QrViewModel : ViewModel() {

    private val repository = FounditApplication.instance.chatRepository

    private val _uiState = MutableStateFlow(QrUiState())
    val uiState: StateFlow<QrUiState> = _uiState.asStateFlow()

    init {
        loadQrItems()
    }

    fun loadQrItems() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            when (val result = repository.getQrItems()) {
                is Result.Success -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    qrItems = result.data
                )
                is Result.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    fun generateQr(name: String, description: String = "") {
        if (name.isBlank()) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isGenerating = true, errorMessage = null)
            when (val result = repository.generateQr(name, description)) {
                is Result.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isGenerating = false,
                        generatedQr = result.data,
                        qrItems = _uiState.value.qrItems + result.data
                    )
                }
                is Result.Error -> _uiState.value = _uiState.value.copy(
                    isGenerating = false,
                    errorMessage = result.message
                )
            }
        }
    }

    fun deleteQrItem(id: String) {
        viewModelScope.launch {
            when (val result = repository.deleteQrItem(id)) {
                is Result.Success -> {
                    val updated = _uiState.value.qrItems.filter { it.id != id }
                    _uiState.value = _uiState.value.copy(qrItems = updated)
                }
                is Result.Error -> _uiState.value = _uiState.value.copy(
                    errorMessage = result.message
                )
            }
        }
    }

    fun clearGeneratedQr() {
        _uiState.value = _uiState.value.copy(generatedQr = null)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    fun clearScanResult() {
        _uiState.value = _uiState.value.copy(scanResultMessage = null)
    }

    /** 解析掃描到的字串並查詢後端（可為完整網址或純 code） */
    fun lookupScannedContent(raw: String) {
        val code = raw.trim().substringAfterLast("/").ifBlank { raw.trim() }
        if (code.isBlank()) return
        viewModelScope.launch {
            when (val r = repository.scanQrCode(code)) {
                is Result.Success -> {
                    val owner = r.data.owner
                    val item = r.data.qrItem
                    val msg = buildString {
                        appendLine(item?.name?.let { "物品：$it" } ?: "防丟標籤")
                        if (owner != null) {
                            appendLine("聯絡人：${owner.name}")
                            append("電話／帳號：${owner.phone}")
                        } else {
                            append("找不到擁有者資訊")
                        }
                    }
                    _uiState.value = _uiState.value.copy(scanResultMessage = msg.trim())
                }
                is Result.Error -> _uiState.value = _uiState.value.copy(errorMessage = r.message)
            }
        }
    }
}
