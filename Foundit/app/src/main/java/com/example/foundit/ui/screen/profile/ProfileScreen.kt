package com.example.foundit.ui.screen.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.example.foundit.ui.component.FounditBottomNavBar
import com.example.foundit.ui.navigation.Screen
import com.example.foundit.ui.screen.auth.AuthViewModel
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.ui.theme.FounditYellow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onNavigateToSettings: () -> Unit,
    onNavigateToPoints: () -> Unit,
    onNavigateToEditProfile: () -> Unit = {},
    onNavigateToItemDetail: (String) -> Unit,
    onLogout: () -> Unit,
    navController: NavController,
    authViewModel: AuthViewModel
) {
    val uiState by authViewModel.uiState.collectAsState()
    var showLogoutDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("我的", color = Color.White) },
                actions = {
                    androidx.compose.material3.IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Filled.Settings, "設定", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        },
        bottomBar = {
            FounditBottomNavBar(navController = navController)
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
        ) {
            // 用戶頭像卡片
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(FounditBlue)
                    .padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = uiState.user?.name?.take(1)?.ifBlank { "?" } ?: "?",
                            style = MaterialTheme.typography.headlineLarge,
                            color = Color.White,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = uiState.user?.name?.ifBlank { "使用者" } ?: "使用者",
                        style = MaterialTheme.typography.titleLarge,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = uiState.user?.phone?.let { "📱 $it" } ?: "",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                    Spacer(Modifier.height(8.dp))
                    TextButton(
                        onClick = onNavigateToEditProfile,
                        colors = androidx.compose.material3.ButtonDefaults.textButtonColors(
                            contentColor = Color.White,
                            containerColor = Color.White.copy(alpha = 0.2f)
                        )
                    ) {
                        Text("編輯個人資料", style = MaterialTheme.typography.labelMedium)
                    }
                }
            }

            // 積分卡片
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .clickable { onNavigateToPoints() },
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = FounditYellow.copy(alpha = 0.1f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Filled.EmojiEvents,
                            contentDescription = null,
                            tint = FounditYellow,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "我的積分",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "${uiState.user?.points ?: 0} 點",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = FounditYellow
                            )
                        }
                    }
                    Icon(
                        Icons.Filled.ChevronRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 功能選單
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column {
                    MenuRow(
                        icon = Icons.Filled.Search,
                        iconColor = FounditOrange,
                        label = "我的遺失物",
                        onClick = { navController.navigate(Screen.Home.route) }
                    )
                    Divider(modifier = Modifier.padding(start = 56.dp))
                    MenuRow(
                        icon = Icons.Filled.FindInPage,
                        iconColor = FounditGreen,
                        label = "我的撿到物",
                        onClick = { navController.navigate(Screen.Home.route) }
                    )
                    Divider(modifier = Modifier.padding(start = 56.dp))
                    MenuRow(
                        icon = Icons.Filled.QrCode,
                        iconColor = FounditBlue,
                        label = "我的 QR 防丟標籤",
                        onClick = { navController.navigate(Screen.Qr.route) }
                    )
                    Divider(modifier = Modifier.padding(start = 56.dp))
                    MenuRow(
                        icon = Icons.Filled.EmojiEvents,
                        iconColor = FounditYellow,
                        label = "積分紀錄",
                        onClick = onNavigateToPoints
                    )
                    Divider(modifier = Modifier.padding(start = 56.dp))
                    MenuRow(
                        icon = Icons.Filled.Settings,
                        iconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                        label = "設定",
                        onClick = onNavigateToSettings
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            // 登出
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                MenuRow(
                    icon = Icons.Filled.ExitToApp,
                    iconColor = MaterialTheme.colorScheme.error,
                    label = "登出",
                    labelColor = MaterialTheme.colorScheme.error,
                    onClick = { showLogoutDialog = true }
                )
            }

            Spacer(Modifier.height(32.dp))
        }
    }

    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("確認登出") },
            text = { Text("確定要登出嗎？") },
            confirmButton = {
                Button(
                    onClick = {
                        showLogoutDialog = false
                        authViewModel.logout(onLogout)
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("登出") }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) { Text("取消") }
            }
        )
    }
}

@Composable
private fun MenuRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    labelColor: Color = Color.Unspecified,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(iconColor.copy(alpha = 0.1f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = iconColor, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(14.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = if (labelColor != Color.Unspecified) labelColor else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(18.dp)
        )
    }
}
