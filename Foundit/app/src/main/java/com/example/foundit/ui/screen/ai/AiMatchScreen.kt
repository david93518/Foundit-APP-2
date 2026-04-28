package com.example.foundit.ui.screen.ai

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.example.foundit.data.model.AiMatchResult
import com.example.foundit.data.model.ItemType
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.getCategoryEmoji
import com.example.foundit.ui.screen.item.ItemViewModel
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AiMatchScreen(
    itemId: String,
    onNavigateToItemDetail: (String) -> Unit,
    onNavigateBack: () -> Unit,
    itemViewModel: ItemViewModel = viewModel()
) {
    val aiState by itemViewModel.aiMatchState.collectAsState()

    LaunchedEffect(itemId) {
        itemViewModel.startAiMatch(itemId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("AI 智慧配對", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // AI 標題說明
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(FounditBlue.copy(alpha = 0.05f))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Filled.AutoAwesome,
                    contentDescription = null,
                    tint = FounditBlue,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "AI 根據物品特徵自動配對最相似的物品",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            when {
                aiState.isLoading -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator(
                            color = FounditBlue,
                            modifier = Modifier.size(56.dp)
                        )
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = "AI 配對分析中，請稍候…",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                aiState.errorMessage != null -> ErrorState(
                    message = aiState.errorMessage!!,
                    onRetry = { itemViewModel.startAiMatch(itemId) }
                )
                aiState.results.isEmpty() -> EmptyState(
                    message = "未找到相似物品\nAI 將持續為您監測新增物品",
                    actionLabel = "重新配對",
                    onAction = { itemViewModel.startAiMatch(itemId) }
                )
                else -> {
                    Text(
                        text = "找到 ${aiState.results.size} 個相似物品",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                    LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(aiState.results) { result ->
                            AiMatchResultCard(
                                result = result,
                                onClick = { onNavigateToItemDetail(result.item.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AiMatchResultCard(
    result: AiMatchResult,
    onClick: () -> Unit
) {
    val item = result.item
    val isLost = item.type == ItemType.LOST
    val accentColor = if (isLost) FounditOrange else FounditGreen

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            // 圖片
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                if (item.images.isNotEmpty()) {
                    AsyncImage(
                        model = item.images.first(),
                        contentDescription = item.title,
                        modifier = Modifier
                            .size(72.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = getCategoryEmoji(item.category),
                        style = MaterialTheme.typography.headlineSmall
                    )
                }
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                // 類型標籤
                Box(
                    modifier = Modifier
                        .background(accentColor.copy(alpha = 0.1f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = item.type.label,
                        style = MaterialTheme.typography.labelSmall,
                        color = accentColor,
                        fontWeight = FontWeight.Medium
                    )
                }

                Text(
                    text = item.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 4.dp)
                )

                Text(
                    text = "${item.category} · ${item.locationName.ifBlank { "未知地點" }}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(Modifier.height(8.dp))

                // 相似度進度條
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "相似度",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(8.dp))
                    LinearProgressIndicator(
                        progress = { result.score },
                        modifier = Modifier
                            .weight(1f)
                            .height(6.dp),
                        color = when {
                            result.score >= 0.8f -> FounditGreen
                            result.score >= 0.6f -> FounditOrange
                            else -> FounditBlue
                        },
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "${result.similarityPercent}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = when {
                            result.score >= 0.8f -> FounditGreen
                            result.score >= 0.6f -> FounditOrange
                            else -> FounditBlue
                        }
                    )
                }
            }
        }
    }
}
