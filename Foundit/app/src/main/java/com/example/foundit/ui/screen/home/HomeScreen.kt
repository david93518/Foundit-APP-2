package com.example.foundit.ui.screen.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.FounditBottomNavBar
import com.example.foundit.ui.component.ItemCard
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToItemDetail: (String) -> Unit,
    onNavigateToAddItem: (String) -> Unit,
    onNavigateToSearch: () -> Unit,
    onNavigateToMap: () -> Unit,
    onNavigateToNotification: () -> Unit,
    navController: NavController,
    homeViewModel: HomeViewModel
) {
    val uiState by homeViewModel.uiState.collectAsState()
    var showAddMenu by remember { mutableStateOf(false) }

    val tabs = listOf("全部", "遺失物", "撿到物")

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "找得到",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                actions = {
                    IconButton(onClick = onNavigateToSearch) {
                        Icon(Icons.Filled.Search, contentDescription = "搜尋", tint = Color.White)
                    }
                    IconButton(onClick = onNavigateToMap) {
                        Icon(Icons.Filled.Map, contentDescription = "地圖", tint = Color.White)
                    }
                    IconButton(onClick = onNavigateToNotification) {
                        Icon(Icons.Filled.Notifications, contentDescription = "通知", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        },
        bottomBar = {
            FounditBottomNavBar(navController = navController)
        },
        floatingActionButton = {
            Column(horizontalAlignment = Alignment.End) {
                if (showAddMenu) {
                    // 新增撿到物
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "撿到物",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier
                                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        SmallFloatingActionButton(
                            onClick = {
                                showAddMenu = false
                                onNavigateToAddItem("found")
                            },
                            containerColor = FounditGreen,
                            contentColor = Color.White,
                            shape = CircleShape
                        ) {
                            Icon(Icons.Filled.FindInPage, contentDescription = "新增撿到物")
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    // 新增遺失物
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "遺失物",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier
                                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        SmallFloatingActionButton(
                            onClick = {
                                showAddMenu = false
                                onNavigateToAddItem("lost")
                            },
                            containerColor = FounditOrange,
                            contentColor = Color.White,
                            shape = CircleShape
                        ) {
                            Icon(Icons.Filled.Add, contentDescription = "新增遺失物")
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }

                FloatingActionButton(
                    onClick = { showAddMenu = !showAddMenu },
                    containerColor = FounditBlue,
                    contentColor = Color.White
                ) {
                    Icon(Icons.Filled.Add, contentDescription = "新增")
                }
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // 分類 Tab
            TabRow(
                selectedTabIndex = uiState.selectedTab,
                containerColor = FounditBlue,
                contentColor = Color.White
            ) {
                tabs.forEachIndexed { index, title ->
                    Tab(
                        selected = uiState.selectedTab == index,
                        onClick = { homeViewModel.onTabSelected(index) },
                        text = {
                            Text(
                                text = title,
                                fontWeight = if (uiState.selectedTab == index) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    )
                }
            }

            // 內容區
            when {
                uiState.isLoading -> LoadingOverlay()
                uiState.errorMessage != null -> ErrorState(
                    message = uiState.errorMessage!!,
                    onRetry = { homeViewModel.loadItems() }
                )
                uiState.items.isEmpty() -> EmptyState(
                    message = "目前沒有物品，\n成為第一個登記的人！",
                    actionLabel = "新增物品",
                    onAction = { onNavigateToAddItem("lost") }
                )
                else -> {
                    PullToRefreshBox(
                        isRefreshing = uiState.isRefreshing,
                        onRefresh = { homeViewModel.loadItems(refresh = true) },
                        modifier = Modifier.fillMaxSize()
                    ) {
                        LazyColumn(
                            contentPadding = PaddingValues(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(
                                items = uiState.items,
                                key = { it.id }
                            ) { item ->
                                ItemCard(
                                    item = item,
                                    onClick = { onNavigateToItemDetail(item.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
