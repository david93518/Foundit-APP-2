package com.example.foundit.ui.screen.qr

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.foundit.data.model.QrItem
import com.example.foundit.ui.component.EmptyState
import com.example.foundit.ui.component.ErrorSnackbar
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.util.Constants
import com.example.foundit.util.QrBitmapShare
import com.example.foundit.util.toDateString
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QrScreen(
    onNavigateBack: () -> Unit,
    qrViewModel: QrViewModel
) {
    val uiState by qrViewModel.uiState.collectAsState()
    val context = LocalContext.current
    var showAddSheet by remember { mutableStateOf(false) }
    var showQrDialog by remember { mutableStateOf<QrItem?>(null) }
    val sheetState = rememberModalBottomSheetState()

    val scanLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val raw = result.data?.getStringExtra(QrScanActivity.EXTRA_QR_CODE).orEmpty()
            if (raw.isNotBlank()) qrViewModel.lookupScannedContent(raw)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("QR 防丟標籤", color = androidx.compose.ui.graphics.Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = androidx.compose.ui.graphics.Color.White)
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            scanLauncher.launch(Intent(context, QrScanActivity::class.java))
                        }
                    ) {
                        Icon(Icons.Filled.QrCodeScanner, "掃描 QR", tint = androidx.compose.ui.graphics.Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = FounditBlue)
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddSheet = true },
                containerColor = FounditBlue,
                contentColor = androidx.compose.ui.graphics.Color.White
            ) {
                Icon(Icons.Filled.Add, "新增 QR")
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // 說明卡片
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = FounditBlue.copy(alpha = 0.08f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Filled.QrCode,
                        contentDescription = null,
                        tint = FounditBlue,
                        modifier = Modifier.size(36.dp)
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(
                        text = "將 QR Code 貼紙貼在您的貴重物品上，撿到者掃描後可立即聯絡您！",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            when {
                uiState.isLoading -> LoadingOverlay()
                uiState.qrItems.isEmpty() -> EmptyState(
                    message = "尚未建立 QR 防丟標籤\n點擊右下角按鈕新增",
                    actionLabel = "新增 QR 標籤",
                    onAction = { showAddSheet = true }
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(items = uiState.qrItems, key = { it.id }) { qrItem ->
                        QrItemCard(
                            qrItem = qrItem,
                            onShowQr = { showQrDialog = qrItem },
                            onDelete = { qrViewModel.deleteQrItem(qrItem.id) }
                        )
                    }
                }
            }
        }

        ErrorSnackbar(message = uiState.errorMessage, onDismiss = qrViewModel::clearError)
    }

    uiState.scanResultMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = qrViewModel::clearScanResult,
            title = { Text("掃描結果") },
            text = { Text(msg) },
            confirmButton = {
                TextButton(onClick = qrViewModel::clearScanResult) { Text("關閉") }
            }
        )
    }

    // 新增 QR 底部表單
    if (showAddSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAddSheet = false },
            sheetState = sheetState
        ) {
            AddQrSheet(
                isLoading = uiState.isGenerating,
                onGenerate = { name, desc ->
                    qrViewModel.generateQr(name, desc)
                    showAddSheet = false
                },
                onDismiss = { showAddSheet = false }
            )
        }
    }

    // 顯示 QR Code 對話框
    showQrDialog?.let { qrItem ->
        QrDisplayDialog(
            qrItem = qrItem,
            onDismiss = { showQrDialog = null }
        )
    }
}

@Composable
private fun QrItemCard(
    qrItem: QrItem,
    onShowQr: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .background(FounditBlue.copy(alpha = 0.1f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.QrCode,
                    contentDescription = null,
                    tint = FounditBlue,
                    modifier = Modifier.size(32.dp)
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = qrItem.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                if (qrItem.description.isNotBlank()) {
                    Text(
                        text = qrItem.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Text(
                    text = "建立：${qrItem.createdAt.toDateString("yyyy/MM/dd")}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = onShowQr) {
                Icon(Icons.Filled.QrCode, "查看 QR", tint = FounditBlue)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Delete, "刪除", tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun AddQrSheet(
    isLoading: Boolean,
    onGenerate: (String, String) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp)
    ) {
        Text("新增 QR 防丟標籤", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(20.dp))

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("物品名稱 *") },
            placeholder = { Text("例如：我的錢包") },
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = description,
            onValueChange = { description = it },
            label = { Text("備註（選填）") },
            placeholder = { Text("例如：黑色皮夾，內有 ID") },
            minLines = 2,
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(20.dp))

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("取消") }
            Button(
                onClick = { onGenerate(name, description) },
                enabled = name.isNotBlank() && !isLoading,
                modifier = Modifier.weight(1f)
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = androidx.compose.ui.graphics.Color.White
                    )
                } else {
                    Text("產生 QR Code")
                }
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun QrDisplayDialog(
    qrItem: QrItem,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val qrBitmap = remember(qrItem.qrCode) {
        generateQrBitmap("${Constants.QR_SCAN_DEEP_LINK}${qrItem.qrCode}")
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(qrItem.name) },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                if (qrBitmap != null) {
                    Image(
                        bitmap = qrBitmap.asImageBitmap(),
                        contentDescription = "QR Code",
                        modifier = Modifier.size(220.dp)
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(220.dp)
                            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "掃描此 QR Code 可聯絡物品擁有者",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(
                    onClick = {
                        qrBitmap?.let { QrBitmapShare.sharePng(context, it) }
                    }
                ) { Text("分享") }
                TextButton(
                    onClick = {
                        val bmp = qrBitmap
                        if (bmp != null) {
                            val uri = QrBitmapShare.saveToGallery(context, bmp)
                            Toast.makeText(
                                context,
                                if (uri != null) "已儲存至相簿「圖片 / Foundit」" else "儲存失敗",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    }
                ) { Text("儲存") }
                TextButton(onClick = onDismiss) { Text("關閉") }
            }
        }
    )
}

/** 使用 ZXing 產生 QR Code Bitmap */
fun generateQrBitmap(content: String, size: Int = Constants.QR_CODE_SIZE_PX): Bitmap? {
    return try {
        val writer = QRCodeWriter()
        val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, size, size)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        for (x in 0 until size) {
            for (y in 0 until size) {
                bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
        bitmap
    } catch (e: Exception) {
        null
    }
}
