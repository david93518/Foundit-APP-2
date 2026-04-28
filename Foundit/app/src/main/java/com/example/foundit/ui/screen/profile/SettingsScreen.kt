package com.example.foundit.ui.screen.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material.icons.filled.QrCode
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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.util.NotificationHelper

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit,
    onLogout: () -> Unit,
    settingsViewModel: SettingsViewModel = viewModel()
) {
    val uiState by settingsViewModel.uiState.collectAsState()
    val context = LocalContext.current
    var showDeleteAccountDialog by remember { mutableStateOf(false) }
    val hasNotifPermission = NotificationHelper.hasNotificationPermission(context)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("設定") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
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
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp)
        ) {

            // ── 通知設定 ──
            SettingsSection(title = "通知設定") {
                if (!hasNotifPermission) {
                    SettingsInfoRow(
                        icon = Icons.Filled.NotificationsOff,
                        iconColor = MaterialTheme.colorScheme.error,
                        label = "通知已停用",
                        subtitle = "點擊前往系統設定開啟通知權限",
                        onClick = { NotificationHelper.openNotificationSettings(context) }
                    )
                    Divider(modifier = Modifier.padding(start = 56.dp))
                }

                SettingsSwitchRow(
                    icon = Icons.Filled.AutoAwesome,
                    iconColor = FounditBlue,
                    label = "AI 配對通知",
                    subtitle = "AI 成功配對相似物品時通知您",
                    checked = uiState.aiMatchNotif && hasNotifPermission,
                    enabled = hasNotifPermission,
                    onCheckedChange = { settingsViewModel.toggleAiMatchNotif() }
                )
                Divider(modifier = Modifier.padding(start = 56.dp))
                SettingsSwitchRow(
                    icon = Icons.Filled.Chat,
                    iconColor = FounditGreen,
                    label = "新訊息通知",
                    subtitle = "收到新的聊天訊息時通知您",
                    checked = uiState.messageNotif && hasNotifPermission,
                    enabled = hasNotifPermission,
                    onCheckedChange = { settingsViewModel.toggleMessageNotif() }
                )
                Divider(modifier = Modifier.padding(start = 56.dp))
                SettingsSwitchRow(
                    icon = Icons.Filled.LocationOn,
                    iconColor = FounditOrange,
                    label = "附近物品提醒",
                    subtitle = "附近有新的遺失物或撿到物時通知您",
                    checked = uiState.nearbyNotif && hasNotifPermission,
                    enabled = hasNotifPermission,
                    onCheckedChange = { settingsViewModel.toggleNearbyNotif() }
                )
                Divider(modifier = Modifier.padding(start = 56.dp))
                SettingsSwitchRow(
                    icon = Icons.Filled.QrCode,
                    iconColor = FounditBlue,
                    label = "QR 掃描通知",
                    subtitle = "有人掃描您的 QR 防丟標籤時通知您",
                    checked = uiState.qrScanNotif && hasNotifPermission,
                    enabled = hasNotifPermission,
                    onCheckedChange = { settingsViewModel.toggleQrScanNotif() }
                )
            }

            Spacer(Modifier.height(12.dp))

            // ── 外觀設定 ──
            SettingsSection(title = "外觀") {
                SettingsSwitchRow(
                    icon = Icons.Filled.DarkMode,
                    iconColor = MaterialTheme.colorScheme.onSurface,
                    label = "深色模式",
                    subtitle = "切換深色/淺色介面",
                    checked = uiState.isDarkMode,
                    onCheckedChange = { settingsViewModel.toggleDarkMode() }
                )
            }

            Spacer(Modifier.height(12.dp))

            // ── 法律 ──
            SettingsSection(title = "隱私與法律") {
                SettingsLinkRow(
                    icon = Icons.Filled.Policy,
                    iconColor = FounditBlue,
                    label = "隱私政策",
                    onClick = {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse("https://foundit.com.tw/privacy"))
                        )
                    }
                )
                Divider(modifier = Modifier.padding(start = 56.dp))
                SettingsLinkRow(
                    icon = Icons.AutoMirrored.Filled.OpenInNew,
                    iconColor = FounditBlue,
                    label = "使用條款",
                    onClick = {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse("https://foundit.com.tw/terms"))
                        )
                    }
                )
            }

            Spacer(Modifier.height(12.dp))

            // ── 關於 ──
            SettingsSection(title = "關於應用程式") {
                SettingsInfoRow(
                    icon = Icons.Filled.Info,
                    iconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    label = "應用程式版本",
                    subtitle = "1.0.0"
                )
                Divider(modifier = Modifier.padding(start = 56.dp))
                SettingsLinkRow(
                    icon = Icons.Filled.Star,
                    iconColor = FounditOrange,
                    label = "為應用程式評分",
                    onClick = {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW,
                                Uri.parse("market://details?id=com.example.foundit"))
                        )
                    }
                )
            }

            Spacer(Modifier.height(12.dp))

            // ── 危險操作 ──
            SettingsSection(title = "帳號") {
                SettingsDangerRow(
                    icon = Icons.Filled.DeleteForever,
                    label = "刪除帳號",
                    subtitle = "永久刪除您的帳號及所有資料",
                    onClick = { showDeleteAccountDialog = true }
                )
            }
        }
    }

    // 刪除帳號確認對話框
    if (showDeleteAccountDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteAccountDialog = false },
            title = { Text("確認刪除帳號") },
            text = {
                Text(
                    "刪除帳號將永久移除您的所有資料，包括：\n" +
                    "• 個人資料\n• 遺失物/撿到物登記\n• 聊天紀錄\n• QR Code 標籤\n• 積分\n\n" +
                    "此操作無法復原。"
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showDeleteAccountDialog = false
                        // TODO: 呼叫 API 刪除帳號
                        onLogout()
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("確認刪除") }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAccountDialog = false }) { Text("取消") }
            }
        )
    }
}

// ── 可重用的設定列元件 ──

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp, top = 8.dp)
        )
        Card(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsSwitchRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    subtitle: String = "",
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SettingsIcon(icon = icon, iconColor = if (enabled) iconColor else Color.Gray)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = if (enabled) MaterialTheme.colorScheme.onSurface
                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
            if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled
        )
    }
}

@Composable
private fun SettingsLinkRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SettingsIcon(icon = icon, iconColor = iconColor)
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
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

@Composable
private fun SettingsInfoRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    subtitle: String = "",
    onClick: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SettingsIcon(icon = icon, iconColor = iconColor)
        Column(modifier = Modifier.weight(1f)) {
            Text(text = label, style = MaterialTheme.typography.bodyMedium)
            if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        if (onClick != null) {
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
private fun SettingsDangerRow(
    icon: ImageVector,
    label: String,
    subtitle: String = "",
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
            modifier = Modifier
                .size(20.dp)
                .padding(end = 0.dp)
        )
        Column(modifier = Modifier.weight(1f).padding(start = 16.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error
            )
            if (subtitle.isNotBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun SettingsIcon(icon: ImageVector, iconColor: Color) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .size(36.dp)
            .padding(end = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(20.dp)
        )
    }
}
