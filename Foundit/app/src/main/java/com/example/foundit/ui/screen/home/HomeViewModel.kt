package com.example.foundit.ui.screen.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.Item
import com.example.foundit.data.remote.ItemFilter
import com.example.foundit.data.repository.Result
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class HomeUiState(
    val isLoading: Boolean = false,
    val items: List<Item> = emptyList(),
    val errorMessage: String? = null,
    val selectedTab: Int = 0,         // 0=全部, 1=遺失物, 2=撿到物
    val searchKeyword: String = "",
    val selectedCategory: String = "",
    val selectedArea: String = "",
    val hasRewardOnly: Boolean = false,
    val isRefreshing: Boolean = false
)

class HomeViewModel : ViewModel() {

    private val repository = FounditApplication.instance.itemRepository

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadItems()
    }

    fun loadItems(refresh: Boolean = false) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = !refresh,
                isRefreshing = refresh,
                errorMessage = null
            )
            val state = _uiState.value
            val typeFilter = when (state.selectedTab) {
                1 -> "LOST"
                2 -> "FOUND"
                else -> null
            }
            val filter = ItemFilter(
                type = typeFilter,
                category = state.selectedCategory.takeIf { it.isNotBlank() },
                area = state.selectedArea.takeIf { it.isNotBlank() },
                keyword = state.searchKeyword.takeIf { it.isNotBlank() },
                hasReward = if (state.hasRewardOnly) true else null
            )
            when (val result = repository.getItems(filter)) {
                is Result.Success -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    isRefreshing = false,
                    items = result.data
                )
                is Result.Error -> _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    isRefreshing = false,
                    errorMessage = result.message
                )
            }
        }
    }

    fun onTabSelected(tab: Int) {
        _uiState.value = _uiState.value.copy(selectedTab = tab)
        loadItems()
    }

    fun onSearchKeywordChanged(keyword: String) {
        _uiState.value = _uiState.value.copy(searchKeyword = keyword)
    }

    fun onSearchSubmit() {
        loadItems()
    }

    fun onCategorySelected(category: String) {
        _uiState.value = _uiState.value.copy(selectedCategory = category)
        loadItems()
    }

    fun onAreaSelected(area: String) {
        _uiState.value = _uiState.value.copy(selectedArea = area)
        loadItems()
    }

    fun onRewardFilterChanged(hasRewardOnly: Boolean) {
        _uiState.value = _uiState.value.copy(hasRewardOnly = hasRewardOnly)
        loadItems()
    }

    fun clearFilters() {
        _uiState.value = _uiState.value.copy(
            selectedCategory = "",
            selectedArea = "",
            hasRewardOnly = false,
            searchKeyword = ""
        )
        loadItems()
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
