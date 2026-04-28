package com.example.foundit.ui.component

import android.Manifest
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import java.io.File

/** 物品相片選取元件（最多 5 張，支援相機/相簿）*/
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun ImagePickerRow(
    images: List<Uri>,
    onImagesChanged: (List<Uri>) -> Unit,
    maxImages: Int = 5,
    modifier: Modifier = Modifier
) {
    var showSourceDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA)

    // 相簿選取（支援多選）
    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxImages)
    ) { uris ->
        val combined = (images + uris).distinct().take(maxImages)
        onImagesChanged(combined)
    }

    // 相機拍照
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && cameraUri != null) {
            val combined = (images + cameraUri!!).distinct().take(maxImages)
            onImagesChanged(combined)
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = "物品照片（${images.size}/$maxImages）",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        LazyRow(
            contentPadding = PaddingValues(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(images) { uri ->
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(8.dp))
                ) {
                    AsyncImage(
                        model = uri,
                        contentDescription = "已選相片",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                    // 刪除按鈕
                    IconButton(
                        onClick = {
                            onImagesChanged(images.filter { it != uri })
                        },
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .size(24.dp)
                            .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(bottomStart = 6.dp))
                    ) {
                        Icon(
                            Icons.Filled.Close,
                            contentDescription = "移除",
                            tint = Color.White,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }
            }

            // 新增按鈕
            if (images.size < maxImages) {
                item {
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .border(
                                1.dp,
                                MaterialTheme.colorScheme.outline,
                                RoundedCornerShape(8.dp)
                            )
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .clickable { showSourceDialog = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                Icons.Filled.Add,
                                contentDescription = "新增相片",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "新增",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }

    // 選擇來源對話框
    if (showSourceDialog) {
        AlertDialog(
            onDismissRequest = { showSourceDialog = false },
            title = { Text("選擇照片來源") },
            text = { Text("您要從哪裡選取照片？") },
            confirmButton = {
                TextButton(onClick = {
                    showSourceDialog = false
                    galleryLauncher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                }) { Text("相簿") }
            },
            dismissButton = {
                TextButton(onClick = {
                    showSourceDialog = false
                    if (cameraPermission.status.isGranted) {
                        val photoFile = File(
                            context.cacheDir,
                            "foundit_cam_${System.currentTimeMillis()}.jpg"
                        )
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            photoFile
                        )
                        cameraUri = uri
                        cameraLauncher.launch(uri)
                    } else {
                        cameraPermission.launchPermissionRequest()
                    }
                }) { Text("相機") }
            }
        )
    }
}
