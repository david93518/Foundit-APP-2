package com.example.foundit.ui.screen.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DockedSearchBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SearchBar
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ItemCard
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.screen.home.HomeViewModel
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.util.Constants

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SearchScreen(
    onNavigateToItemDetail: (String) -> Unit,
    onNavigateBack: () -> Unit,
    homeViewModel: HomeViewModel
) {
    val uiState by homeViewModel.uiState.collectAsState()
    var showFilterSheet by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("搜尋") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
                    }
                },
                actions = {
                    IconButton(onClick = { showFilterSheet = true }) {
                        Icon(Icons.Filled.FilterList, "篩選", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FounditBlue,
                    titleContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // 搜尋列
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                DockedSearchBar(
                    query = uiState.searchKeyword,
                    onQueryChange = homeViewModel::onSearchKeywordChanged,
                    onSearch = { homeViewModel.onSearchSubmit() },
                    active = false,
                    onActiveChange = {},
                    placeholder = { Text("搜尋物品名稱、描述…") },
                    leadingIcon = { Icon(Icons.Filled.Search, null) },
                    trailingIcon = {
                        if (uiState.searchKeyword.isNotBlank()) {
                            IconButton(onClick = {
                                homeViewModel.onSearchKeywordChanged("")
                                homeViewModel.onSearchSubmit()
                            }) {
                                Icon(Icons.Filled.Close, "清除")
                            }
                        }
                    },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {}
            }

            // 已選篩選條件
            val hasFilters = uiState.selectedCategory.isNotBlank() ||
                    uiState.selectedArea.isNotBlank() ||
                    uiState.hasRewardOnly
            if (hasFilters) {
                FlowRow(
                    modifier = Modifier.padding(horizontal = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (uiState.selectedCategory.isNotBlank()) {
                        FilterChip(
                            selected = true,
                            onClick = { homeViewModel.onCategorySelected("") },
                            label = { Text(uiState.selectedCategory) },
                            trailingIcon = { Icon(Icons.Filled.Close, null) }
                        )
                    }
                    if (uiState.selectedArea.isNotBlank()) {
                        FilterChip(
                            selected = true,
                            onClick = { homeViewModel.onAreaSelected("") },
                            label = { Text(uiState.selectedArea) },
                            trailingIcon = { Icon(Icons.Filled.Close, null) }
                        )
                    }
                    if (uiState.hasRewardOnly) {
                        FilterChip(
                            selected = true,
                            onClick = { homeViewModel.onRewardFilterChanged(false) },
                            label = { Text("有懸賞") },
                            trailingIcon = { Icon(Icons.Filled.Close, null) }
                        )
                    }
                    TextButton(onClick = homeViewModel::clearFilters) {
                        Text("清除全部")
                    }
                }
            }

            // 結果列表
            when {
                uiState.isLoading -> LoadingOverlay()
                uiState.items.isEmpty() -> EmptyState(message = "找不到符合條件的物品")
                else -> LazyColumn(
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(items = uiState.items, key = { it.id }) { item ->
                        ItemCard(item = item, onClick = { onNavigateToItemDetail(item.id) })
                    }
                }
            }
        }
    }

    // 篩選底部選單
    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = sheetState
        ) {
            FilterBottomSheet(
                selectedCategory = uiState.selectedCategory,
                selectedArea = uiState.selectedArea,
                hasRewardOnly = uiState.hasRewardOnly,
                onCategorySelected = {
                    homeViewModel.onCategorySelected(it)
                    showFilterSheet = false
                },
                onAreaSelected = {
                    homeViewModel.onAreaSelected(it)
                    showFilterSheet = false
                },
                onRewardChanged = { homeViewModel.onRewardFilterChanged(it) },
                onApply = { showFilterSheet = false },
                onClear = {
                    homeViewModel.clearFilters()
                    showFilterSheet = false
                }
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FilterBottomSheet(
    selectedCategory: String,
    selectedArea: String,
    hasRewardOnly: Boolean,
    onCategorySelected: (String) -> Unit,
    onAreaSelected: (String) -> Unit,
    onRewardChanged: (Boolean) -> Unit,
    onApply: () -> Unit,
    onClear: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text("篩選條件", style = MaterialTheme.typography.titleLarge)

        Spacer(Modifier.height(16.dp))
        Text("分類", style = MaterialTheme.typography.titleSmall)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Constants.ITEM_CATEGORIES.forEach { cat ->
                FilterChip(
                    selected = selectedCategory == cat,
                    onClick = { onCategorySelected(if (selectedCategory == cat) "" else cat) },
                    label = { Text(cat) }
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        Text("地區", style = MaterialTheme.typography.titleSmall)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Constants.AREAS.drop(1).forEach { area ->
                FilterChip(
                    selected = selectedArea == area,
                    onClick = { onAreaSelected(if (selectedArea == area) "" else area) },
                    label = { Text(area) }
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        FilterChip(
            selected = hasRewardOnly,
            onClick = { onRewardChanged(!hasRewardOnly) },
            label = { Text("⭐ 只顯示有懸賞") }
        )

        Spacer(Modifier.height(24.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            TextButton(
                onClick = onClear,
                modifier = Modifier.weight(1f)
            ) { Text("清除全部") }
            androidx.compose.material3.Button(
                onClick = onApply,
                modifier = Modifier.weight(1f)
            ) { Text("套用篩選") }
        }

        Spacer(Modifier.height(16.dp))
    }
}
