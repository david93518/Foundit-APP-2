package com.example.foundit.ui.screen.item

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.ItemStatus
import com.example.foundit.data.model.ItemType
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.component.getCategoryEmoji
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.ui.theme.FounditYellow
import com.example.foundit.util.toDateString
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ItemDetailScreen(
    itemId: String,
    onNavigateBack: () -> Unit,
    onNavigateToChat: (String, String, Boolean) -> Unit,
    onNavigateToAiMatch: () -> Unit,
    onNavigateToEdit: () -> Unit,
    itemViewModel: ItemViewModel
) {
    val detailState by itemViewModel.detailState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf(false) }
    var myUserId by remember { mutableStateOf<String?>(null) }

    // 持續訂閱 userId，登出／換帳號後才會即時更新，避免仍用舊帳號 id 誤判為發布者
    LaunchedEffect(Unit) {
        FounditApplication.instance.preferences.userId.collect { id ->
            myUserId = id
        }
    }

    LaunchedEffect(itemId) {
        itemViewModel.loadItem(itemId)
    }

    LaunchedEffect(detailState.isResolved) {
        if (detailState.isResolved) onNavigateBack()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("物品詳情") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
                    }
                },
                actions = {
                    detailState.item?.let { item ->
                        val isOwner = isItemOwner(item.userId, myUserId)
                        if (isOwner) {
                            IconButton(onClick = onNavigateToEdit) {
                                Icon(Icons.Filled.Edit, "編輯", tint = Color.White)
                            }
                            IconButton(onClick = { showDeleteDialog = true }) {
                                Icon(Icons.Filled.Delete, "刪除", tint = Color.White)
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        }
    ) { padding ->
        when {
            detailState.isLoading -> LoadingOverlay()
            detailState.errorMessage != null -> ErrorState(
                message = detailState.errorMessage!!,
                onRetry = { itemViewModel.loadItem(itemId) }
            )
            detailState.item != null -> {
                val item = detailState.item!!
                val isLost = item.type == ItemType.LOST
                val isOwner = isItemOwner(item.userId, myUserId)
                val accentColor = if (isLost) FounditOrange else FounditGreen

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .verticalScroll(rememberScrollState())
                ) {
                    // 圖片區
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(16f / 9f)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                        contentAlignment = Alignment.Center
                    ) {
                        if (item.images.isNotEmpty()) {
                            AsyncImage(
                                model = item.images.first(),
                                contentDescription = item.title,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                        } else {
                            Text(
                                text = getCategoryEmoji(item.category),
                                style = MaterialTheme.typography.displayLarge
                            )
                        }

                        // 類型標籤（左上角）
                        Box(
                            modifier = Modifier
                                .align(Alignment.TopStart)
                                .padding(12.dp)
                                .background(accentColor, RoundedCornerShape(8.dp))
                                .padding(horizontal = 10.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = item.type.label,
                                color = Color.White,
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        // 狀態標籤（右上角）
                        if (item.status != ItemStatus.ACTIVE) {
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(12.dp)
                                    .background(
                                        if (item.status == ItemStatus.RESOLVED) FounditGreen else Color.Gray,
                                        RoundedCornerShape(8.dp)
                                    )
                                    .padding(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Text(
                                    text = item.status.label,
                                    color = Color.White,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }

                    Column(modifier = Modifier.padding(16.dp)) {
                        // 標題 & 賞金
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.Top
                        ) {
                            Text(
                                text = item.title,
                                style = MaterialTheme.typography.headlineSmall,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.weight(1f)
                            )
                            if (item.hasReward && item.reward > 0) {
                                Column(horizontalAlignment = Alignment.End) {
                                    Icon(
                                        Icons.Filled.Star,
                                        contentDescription = "懸賞",
                                        tint = FounditYellow,
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Text(
                                        text = "NT\$ ${"%,d".format(item.reward)}",
                                        style = MaterialTheme.typography.titleSmall,
                                        color = FounditYellow,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        // 分類標籤
                        Box(
                            modifier = Modifier
                                .padding(top = 6.dp)
                                .background(accentColor.copy(alpha = 0.1f), RoundedCornerShape(6.dp))
                                .padding(horizontal = 10.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = item.category,
                                style = MaterialTheme.typography.labelMedium,
                                color = accentColor
                            )
                        }

                        Spacer(Modifier.height(12.dp))
                        Divider()
                        Spacer(Modifier.height(12.dp))

                        // 地點 & 時間
                        InfoRow(
                            icon = { Icon(Icons.Filled.LocationOn, null, tint = accentColor, modifier = Modifier.size(18.dp)) },
                            label = if (isLost) "遺失地點" else "撿到地點",
                            value = item.locationName.ifBlank { "未提供" }
                        )
                        Spacer(Modifier.height(8.dp))
                        InfoRow(
                            icon = { Icon(Icons.Filled.Schedule, null, tint = accentColor, modifier = Modifier.size(18.dp)) },
                            label = if (isLost) "遺失時間" else "撿到時間",
                            value = item.lostAt.toDateString()
                        )

                        if (item.color.isNotBlank()) {
                            Spacer(Modifier.height(8.dp))
                            InfoRow(
                                icon = { Text("🎨") },
                                label = "顏色",
                                value = item.color
                            )
                        }

                        if (!isLost && item.storageLocation.isNotBlank()) {
                            Spacer(Modifier.height(8.dp))
                            InfoRow(
                                icon = { Text("📦") },
                                label = "存放地點",
                                value = item.storageLocation
                            )
                        }

                        if (!isLost && item.handedToPolice) {
                            Spacer(Modifier.height(8.dp))
                            InfoRow(
                                icon = { Text("🚔") },
                                label = "已移交警察局",
                                value = "是"
                            )
                        }

                        // 描述
                        if (item.description.isNotBlank()) {
                            Spacer(Modifier.height(12.dp))
                            Divider()
                            Spacer(Modifier.height(12.dp))
                            Text(
                                text = "詳細描述",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = item.description,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 6.dp)
                            )
                        }

                        Spacer(Modifier.height(16.dp))
                        Divider()
                        Spacer(Modifier.height(16.dp))

                        // 發布者
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(accentColor.copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = item.userName.take(1).ifBlank { "?" },
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = accentColor
                                )
                            }
                            Spacer(Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = item.userName.ifBlank { "匿名使用者" },
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Medium
                                )
                                Text(
                                    text = "發布於 ${item.createdAt.toDateString("MM/dd HH:mm")}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Spacer(Modifier.height(24.dp))

                        // 操作按鈕
                        if (item.status == ItemStatus.ACTIVE) {
                            // 僅非發布者可聯絡 PO（避免自己跟自己開聊天室）
                            if (!isOwner) {
                                Button(
                                    onClick = {
                                        onNavigateToChat(item.id, item.title, true)
                                    },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(52.dp),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Icon(Icons.Filled.Chat, null, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("聯絡發布者", style = MaterialTheme.typography.labelLarge)
                                }

                                Spacer(Modifier.height(8.dp))
                            }

                            // AI 配對
                            OutlinedButton(
                                onClick = onNavigateToAiMatch,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(52.dp),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Filled.AutoAwesome, null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("AI 智慧配對", style = MaterialTheme.typography.labelLarge)
                            }

                            Spacer(Modifier.height(8.dp))

                            // 標記已找到（僅遺失物、且為發布者）
                            if (isLost && isOwner) {
                                OutlinedButton(
                                    onClick = { itemViewModel.resolveItem(item.id) },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(52.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = ButtonDefaults.outlinedButtonColors(
                                        contentColor = FounditGreen
                                    )
                                ) {
                                    Icon(Icons.Filled.CheckCircle, null, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("標記已找到", style = MaterialTheme.typography.labelLarge)
                                }
                            }
                        }

                        Spacer(Modifier.height(32.dp))
                    }
                }
            }
        }
    }

    // 刪除確認對話框
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("確認刪除") },
            text = { Text("確定要刪除這個物品嗎？此操作無法復原。") },
            confirmButton = {
                Button(
                    onClick = {
                        showDeleteDialog = false
                        itemViewModel.deleteItem(itemId, onNavigateBack)
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("刪除") }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("取消") }
            }
        )
    }
}

/** 與後端 UUID 比對（忽略空白與大小寫） */
private fun isItemOwner(itemOwnerId: String, currentUserId: String?): Boolean {
    if (currentUserId.isNullOrBlank() || itemOwnerId.isBlank()) return false
    return currentUserId.trim().equals(itemOwnerId.trim(), ignoreCase = true)
}

@Composable
private fun InfoRow(
    icon: @Composable () -> Unit,
    label: String,
    value: String
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        icon()
        Spacer(Modifier.width(8.dp))
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

