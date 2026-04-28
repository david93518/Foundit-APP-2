package com.example.foundit.ui.screen.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.FounditBottomNavBar
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.util.toRelativeTime

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatListScreen(
    onNavigateToChatRoom: (String, String) -> Unit,
    navController: NavController,
    chatViewModel: ChatViewModel
) {
    val uiState by chatViewModel.chatListState.collectAsState()
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(Unit) {
        chatViewModel.loadChats()
    }

    DisposableEffect(lifecycleOwner) {
        val obs = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) chatViewModel.loadChats()
        }
        lifecycleOwner.lifecycle.addObserver(obs)
        onDispose { lifecycleOwner.lifecycle.removeObserver(obs) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("聊天", color = Color.White) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        },
        bottomBar = {
            FounditBottomNavBar(
                navController = navController,
                unreadMessageCount = uiState.chats.sumOf { it.unreadCount }
            )
        }
    ) { padding ->
        when {
            uiState.isLoading -> LoadingOverlay()
            uiState.errorMessage != null -> ErrorState(
                message = uiState.errorMessage!!,
                onRetry = chatViewModel::loadChats
            )
            uiState.chats.isEmpty() -> EmptyState(
                message = "還沒有任何聊天記錄\n找到感興趣的物品後可聯絡發布者"
            )
            else -> LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                items(items = uiState.chats, key = { it.id }) { chat ->
                    ChatListItem(
                        chat = chat,
                        onClick = { onNavigateToChatRoom(chat.id, chat.itemTitle) }
                    )
                    Divider(modifier = Modifier.padding(start = 72.dp))
                }
            }
        }
    }
}

@Composable
private fun ChatListItem(
    chat: com.example.foundit.data.model.Chat,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 頭像
        BadgedBox(
            badge = {
                if (chat.unreadCount > 0) {
                    Badge { Text(text = chat.unreadCount.toString()) }
                }
            }
        ) {
            Box(
                modifier = Modifier
                    .size(50.dp)
                    .clip(CircleShape)
                    .background(FounditBlue.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = chat.otherUserName.take(1).ifBlank { "?" },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = FounditBlue
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = chat.otherUserName.ifBlank { "使用者" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = if (chat.unreadCount > 0) FontWeight.Bold else FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = if (chat.lastMessageAt > 0L) chat.lastMessageAt.toRelativeTime() else "",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (chat.itemTitle.isNotBlank()) {
                Text(
                    text = "[${chat.itemTitle}]",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Text(
                text = chat.lastMessage.ifBlank { "開始對話…" },
                style = MaterialTheme.typography.bodySmall,
                color = if (chat.unreadCount > 0)
                    MaterialTheme.colorScheme.onSurface
                else
                    MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = if (chat.unreadCount > 0) FontWeight.Medium else FontWeight.Normal,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
