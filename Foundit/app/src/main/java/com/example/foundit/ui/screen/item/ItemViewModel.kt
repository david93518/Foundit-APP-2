package com.example.foundit.ui.screen.item

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.AiMatchResult
import com.example.foundit.data.model.Item
import com.example.foundit.data.model.ItemRequest
import com.example.foundit.data.model.ItemType
import com.example.foundit.data.repository.Result
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ItemDetailUiState(
    val isLoading: Boolean = false,
    val item: Item? = null,
    val errorMessage: String? = null,
    val isDeleting: Boolean = false,
    val isResolved: Boolean = false
)

data class AddItemUiState(
    val isLoading: Boolean = false,
    val successItemId: String? = null,
    val errorMessage: String? = null,
    val editItem: Item? = null
)

data class AiMatchUiState(
    val isLoading: Boolean = false,
    val results: List<AiMatchResult> = emptyList(),
    val errorMessage: String? = null
)

class ItemViewModel : ViewModel() {

    private val repository = FounditApplication.instance.itemRepository
    private val app = FounditApplication.instance

    private val _detailState = MutableStateFlow(ItemDetailUiState())
    val detailState: StateFlow<ItemDetailUiState> = _detailState.asStateFlow()

    private val _addState = MutableStateFlow(AddItemUiState())
    val addState: StateFlow<AddItemUiState> = _addState.asStateFlow()

    private val _aiMatchState = MutableStateFlow(AiMatchUiState())
    val aiMatchState: StateFlow<AiMatchUiState> = _aiMatchState.asStateFlow()

    /** 載入物品詳情 */
    fun loadItem(itemId: String) {
        viewModelScope.launch {
            val prev = _detailState.value.item
            val clearStaleItem = prev != null && prev.id != itemId
            _detailState.value = _detailState.value.copy(
                isLoading = true,
                errorMessage = null,
                item = if (clearStaleItem) null else prev,
                isResolved = false
            )
            when (val result = repository.getItem(itemId)) {
                is Result.Success -> _detailState.value = _detailState.value.copy(
                    isLoading = false,
                    item = result.data
                )
                is Result.Error -> _detailState.value = _detailState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 載入要編輯的物品 */
    fun loadItemForEdit(itemId: String) {
        viewModelScope.launch {
            _addState.value = _addState.value.copy(isLoading = true)
            when (val result = repository.getItem(itemId)) {
                is Result.Success -> _addState.value = _addState.value.copy(
                    isLoading = false,
                    editItem = result.data
                )
                is Result.Error -> _addState.value = _addState.value.copy(
                    isLoading = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 建立物品（會先上傳本機相簿/相機圖片） */
    fun createItem(
        type: ItemType,
        title: String,
        category: String,
        description: String,
        color: String,
        imageUris: List<Uri>,
        latitude: Double,
        longitude: Double,
        locationName: String,
        lostAt: Long,
        reward: Int,
        hasReward: Boolean,
        storageLocation: String = "",
        handedToPolice: Boolean = false
    ) {
        viewModelScope.launch {
            _addState.value = _addState.value.copy(isLoading = true, errorMessage = null)
            when (val resolved = resolveImageUrls(imageUris)) {
                is Result.Error -> _addState.value = _addState.value.copy(
                    isLoading = false,
                    errorMessage = resolved.message
                )
                is Result.Success -> {
                    val request = ItemRequest(
                        type = type.name,
                        title = title,
                        category = category,
                        description = description,
                        color = color,
                        images = resolved.data,
                        latitude = latitude,
                        longitude = longitude,
                        locationName = locationName,
                        lostAt = lostAt,
                        reward = reward,
                        hasReward = hasReward,
                        storageLocation = storageLocation,
                        handedToPolice = handedToPolice
                    )
                    when (val result = repository.createItem(request)) {
                        is Result.Success -> _addState.value = _addState.value.copy(
                            isLoading = false,
                            successItemId = result.data.id
                        )
                        is Result.Error -> _addState.value = _addState.value.copy(
                            isLoading = false,
                            errorMessage = result.message
                        )
                    }
                }
            }
        }
    }

    /** 更新物品 */
    fun updateItem(
        itemId: String,
        type: ItemType,
        title: String,
        category: String,
        description: String,
        color: String,
        imageUris: List<Uri>,
        latitude: Double,
        longitude: Double,
        locationName: String,
        lostAt: Long,
        reward: Int,
        hasReward: Boolean,
        storageLocation: String = "",
        handedToPolice: Boolean = false
    ) {
        viewModelScope.launch {
            _addState.value = _addState.value.copy(isLoading = true, errorMessage = null)
            when (val resolved = resolveImageUrls(imageUris)) {
                is Result.Error -> _addState.value = _addState.value.copy(
                    isLoading = false,
                    errorMessage = resolved.message
                )
                is Result.Success -> {
                    val request = ItemRequest(
                        type = type.name,
                        title = title,
                        category = category,
                        description = description,
                        color = color,
                        images = resolved.data,
                        latitude = latitude,
                        longitude = longitude,
                        locationName = locationName,
                        lostAt = lostAt,
                        reward = reward,
                        hasReward = hasReward,
                        storageLocation = storageLocation,
                        handedToPolice = handedToPolice
                    )
                    when (val result = repository.updateItem(itemId, request)) {
                        is Result.Success -> _addState.value = _addState.value.copy(
                            isLoading = false,
                            successItemId = result.data.id
                        )
                        is Result.Error -> _addState.value = _addState.value.copy(
                            isLoading = false,
                            errorMessage = result.message
                        )
                    }
                }
            }
        }
    }

    private suspend fun resolveImageUrls(uris: List<Uri>): Result<List<String>> {
        val out = mutableListOf<String>()
        for (uri in uris) {
            when (uri.scheme?.lowercase()) {
                "http", "https" -> out.add(uri.toString())
                else -> {
                    val cr = app.contentResolver
                    val mime = cr.getType(uri) ?: "image/jpeg"
                    val bytes = try {
                        cr.openInputStream(uri)?.use { it.readBytes() }
                    } catch (e: Exception) {
                        return Result.Error("無法讀取圖片：${e.localizedMessage}")
                    }
                    if (bytes == null || bytes.isEmpty()) {
                        return Result.Error("圖片內容空白")
                    }
                    val ext = when {
                        mime.contains("png") -> "png"
                        mime.contains("webp") -> "webp"
                        else -> "jpg"
                    }
                    val name = "upload_${System.currentTimeMillis()}_${out.size}.$ext"
                    when (val up = repository.uploadImage(bytes, name, mime)) {
                        is Result.Success -> out.add(up.data)
                        is Result.Error -> return up
                    }
                }
            }
        }
        return Result.Success(out)
    }

    /** 刪除物品 */
    fun deleteItem(itemId: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(isDeleting = true)
            when (val result = repository.deleteItem(itemId)) {
                is Result.Success -> {
                    _detailState.value = _detailState.value.copy(isDeleting = false)
                    onSuccess()
                }
                is Result.Error -> _detailState.value = _detailState.value.copy(
                    isDeleting = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 標記已找到 */
    fun resolveItem(itemId: String) {
        viewModelScope.launch {
            when (val result = repository.resolveItem(itemId)) {
                is Result.Success -> _detailState.value = _detailState.value.copy(isResolved = true)
                is Result.Error -> _detailState.value = _detailState.value.copy(
                    errorMessage = result.message
                )
            }
        }
    }

    /** AI 配對 */
    fun startAiMatch(itemId: String) {
        viewModelScope.launch {
            _aiMatchState.value = AiMatchUiState(isLoading = true)
            when (val result = repository.aiMatch(itemId = itemId)) {
                is Result.Success -> _aiMatchState.value = AiMatchUiState(results = result.data)
                is Result.Error -> _aiMatchState.value = AiMatchUiState(errorMessage = result.message)
            }
        }
    }

    fun clearAddState() {
        _addState.value = AddItemUiState()
    }

    fun clearDetailError() {
        _detailState.value = _detailState.value.copy(errorMessage = null)
    }
}
