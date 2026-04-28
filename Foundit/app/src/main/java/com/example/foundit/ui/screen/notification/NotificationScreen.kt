package com.example.foundit.ui.screen.notification

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.Notification
import com.example.foundit.data.model.NotificationType
import com.example.foundit.data.repository.Result
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ErrorState
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.ui.theme.FounditYellow
import com.example.foundit.util.toRelativeTime
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationScreen(
    onNavigateBack: () -> Unit,
    onNavigateToItemDetail: (String) -> Unit
) {
    val chatRepository = FounditApplication.instance.chatRepository
    val coroutineScope = rememberCoroutineScope()

    var isLoading by remember { mutableStateOf(true) }
    var notifications by remember { mutableStateOf<List<Notification>>(emptyList()) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var reloadKey by remember { mutableStateOf(0) }

    LaunchedEffect(reloadKey) {
        isLoading = true
        errorMessage = null
        when (val result = chatRepository.getNotifications()) {
            is Result.Success -> {
                notifications = result.data
                isLoading = false
            }
            is Result.Error -> {
                errorMessage = result.message
                isLoading = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("通知", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
                    }
                },
                actions = {
                    if (notifications.any { !it.isRead }) {
                        TextButton(onClick = {
                            coroutineScope.launch {
                                chatRepository.markAllNotificationsRead()
                                notifications = notifications.map { it.copy(isRead = true) }
                            }
                        }) {
                            Text("全部已讀", color = Color.White)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        }
    ) { padding ->
        when {
            isLoading -> LoadingOverlay()
            errorMessage != null -> ErrorState(
                message = errorMessage!!,
                onRetry = {
                    errorMessage = null
                    reloadKey++
                }
            )
            notifications.isEmpty() -> EmptyState(message = "尚無通知")
            else -> LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                items(items = notifications, key = { it.id }) { notification ->
                    NotificationItem(
                        notification = notification,
                        onClick = {
                            notification.itemId?.let { onNavigateToItemDetail(it) }
                            if (!notification.isRead) {
                                coroutineScope.launch {
                                    chatRepository.markNotificationRead(notification.id)
                                    notifications = notifications.map {
                                        if (it.id == notification.id) it.copy(isRead = true) else it
                                    }
                                }
                            }
                        }
                    )
                    Divider(modifier = Modifier.padding(start = 72.dp))
                }
            }
        }
    }
}

@Composable
private fun NotificationItem(
    notification: Notification,
    onClick: () -> Unit
) {
    val (icon, iconColor) = getNotificationIconAndColor(notification.type)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(
                if (!notification.isRead) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.08f)
                else Color.Transparent
            )
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .background(iconColor.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = iconColor, modifier = Modifier.size(22.dp))
        }

        Spacer(Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = notification.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = if (!notification.isRead) FontWeight.Bold else FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = notification.createdAt.toRelativeTime(),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = notification.content,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp)
            )
        }

        // 未讀紅點
        if (!notification.isRead) {
            Spacer(Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(MaterialTheme.colorScheme.error, CircleShape)
                    .align(Alignment.CenterVertically)
            )
        }
    }
}

private fun getNotificationIconAndColor(type: NotificationType): Pair<ImageVector, Color> =
    when (type) {
        NotificationType.AI_MATCH -> Icons.Filled.AutoAwesome to FounditBlue
        NotificationType.NEW_MESSAGE -> Icons.Filled.Chat to FounditGreen
        NotificationType.NEARBY_ITEM -> Icons.Filled.LocationOn to FounditOrange
        NotificationType.QR_SCAN -> Icons.Filled.QrCode to FounditBlue
        NotificationType.REWARD -> Icons.Filled.Star to FounditYellow
        NotificationType.SYSTEM -> Icons.Filled.Notifications to Color.Gray
    }
