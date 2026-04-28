package com.example.foundit.ui.screen.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
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
import com.example.foundit.data.model.Message
import com.example.foundit.data.model.MessageType
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.util.toDateString
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatRoomScreen(
    chatId: String,
    itemTitle: String,
    openAsItem: Boolean,
    onNavigateBack: () -> Unit,
    chatViewModel: ChatViewModel
) {
    val uiState by chatViewModel.chatRoomState.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(chatId, openAsItem) {
        chatViewModel.enterRoom(chatId, openAsItem)
    }

    val resolvedChatId = uiState.resolvedChatId
    DisposableEffect(resolvedChatId) {
        if (resolvedChatId != null) {
            chatViewModel.attachRealtime(resolvedChatId)
            onDispose { chatViewModel.disconnectRealtime() }
        } else {
            onDispose { }
        }
    }

    // 新訊息時自動滾到底部（避免 index 尚未就緒或重複 key 以外的捲動例外導致崩潰）
    LaunchedEffect(uiState.messages.size, uiState.messages.lastOrNull()?.id) {
        val n = uiState.messages.size
        if (n <= 0) return@LaunchedEffect
        val lastIdx = n - 1
        delay(32)
        try {
            listState.animateScrollToItem(lastIdx)
        } catch (_: Exception) {
            try {
                listState.scrollToItem(lastIdx)
            } catch (_: Exception) { }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "聊天室",
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White
                        )
                        Text(
                            text = itemTitle,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                },
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
                .imePadding()
        ) {
            if (!uiState.isLoading && uiState.errorMessage != null && resolvedChatId == null) {
                ErrorState(
                    message = uiState.errorMessage!!,
                    onRetry = { chatViewModel.enterRoom(chatId, openAsItem) },
                    modifier = Modifier.weight(1f)
                )
            } else {
                // 訊息列表
                if (uiState.isLoading) {
                    LoadingOverlay(modifier = Modifier.weight(1f))
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        state = listState,
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        itemsIndexed(
                            items = uiState.messages,
                            key = { index, message ->
                                if (message.id.isNotBlank()) message.id
                                else "row_${index}_${message.createdAt}_${message.content.hashCode()}"
                            }
                        ) { _, message ->
                            when (message.type) {
                                MessageType.SYSTEM -> SystemNoticeRow(
                                    content = message.content,
                                    timestamp = message.createdAt
                                )
                                else -> {
                                    val isMine = isMyChatBubble(
                                        selfNorm = uiState.selfUserIdNormalized,
                                        message = message
                                    )
                                    MessageBubble(
                                        content = message.content,
                                        isMine = isMine,
                                        senderName = message.senderName,
                                        timestamp = message.createdAt,
                                        isRead = message.isRead
                                    )
                                }
                            }
                        }
                    }
                }

                Divider()

                // 輸入列
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                        .navigationBarsPadding(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = inputText,
                        onValueChange = { inputText = it },
                        placeholder = { Text("輸入訊息…") },
                        maxLines = 4,
                        shape = RoundedCornerShape(24.dp),
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    IconButton(
                        onClick = {
                            if (inputText.isNotBlank() && resolvedChatId != null) {
                                chatViewModel.sendMessage(resolvedChatId, inputText)
                                inputText = ""
                            }
                        },
                        enabled = inputText.isNotBlank() && !uiState.isSending && resolvedChatId != null,
                        modifier = Modifier
                            .size(48.dp)
                            .background(
                                color = if (inputText.isNotBlank()) FounditBlue else MaterialTheme.colorScheme.outline,
                                shape = CircleShape
                            )
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.Send,
                            contentDescription = "傳送",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

private fun normalizeChatUserIdForUi(raw: String): String =
    raw.trim().lowercase().replace("-", "")

/** 自己的訊息靠右；對方靠左。sender_id 空白時視為對方，避免誤判成自己。 */
private fun isMyChatBubble(selfNorm: String, message: Message): Boolean {
    if (message.type == MessageType.SYSTEM) return false
    val sid = normalizeChatUserIdForUi(message.senderId)
    return selfNorm.isNotBlank() && sid.isNotBlank() && selfNorm == sid
}

@Composable
private fun SystemNoticeRow(content: String, timestamp: Long) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = content,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.75f),
                    RoundedCornerShape(12.dp)
                )
                .padding(horizontal = 14.dp, vertical = 8.dp)
        )
        Text(
            text = timestamp.toDateString("HH:mm"),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline,
            modifier = Modifier.padding(top = 4.dp)
        )
    }
}

@Composable
private fun MessageBubble(
    content: String,
    isMine: Boolean,
    senderName: String,
    timestamp: Long,
    isRead: Boolean
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start
    ) {
        if (!isMine) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(FounditBlue.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = senderName.take(1).ifBlank { "?" },
                    style = MaterialTheme.typography.labelMedium,
                    color = FounditBlue
                )
            }
            Spacer(Modifier.width(6.dp))
        }

        Column(
            horizontalAlignment = if (isMine) Alignment.End else Alignment.Start
        ) {
            if (!isMine && senderName.isNotBlank()) {
                Text(
                    text = senderName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 4.dp, bottom = 2.dp)
                )
            }

            Box(
                modifier = Modifier
                    .widthIn(max = 260.dp)
                    .background(
                        color = if (isMine) FounditBlue else MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(
                            topStart = 16.dp,
                            topEnd = 16.dp,
                            bottomStart = if (isMine) 16.dp else 4.dp,
                            bottomEnd = if (isMine) 4.dp else 16.dp
                        )
                    )
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    text = content,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isMine) Color.White else MaterialTheme.colorScheme.onSurface
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 2.dp, start = 4.dp, end = 4.dp)
            ) {
                Text(
                    text = timestamp.toDateString("HH:mm"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (isMine) {
                    Spacer(Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Filled.DoneAll,
                        contentDescription = if (isRead) "已讀" else "已送達",
                        tint = if (isRead) Color.White.copy(alpha = 0.95f) else Color.White.copy(alpha = 0.55f),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

