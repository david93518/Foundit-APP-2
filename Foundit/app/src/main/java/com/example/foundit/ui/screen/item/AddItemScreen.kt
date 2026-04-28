package com.example.foundit.ui.screen.item

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
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.window.Dialog
import com.example.foundit.data.model.ItemType
import com.example.foundit.ui.component.ErrorSnackbar
import com.example.foundit.ui.component.ImagePickerRow
import com.example.foundit.ui.component.LoadingOverlay
import com.example.foundit.ui.component.LocationPickerSheet
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.util.Constants
import com.example.foundit.util.toDateString
import java.util.Calendar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemScreen(
    itemType: String,
    editItemId: String? = null,
    onSubmitSuccess: (String) -> Unit,
    onNavigateBack: () -> Unit,
    itemViewModel: ItemViewModel
) {
    val addState by itemViewModel.addState.collectAsState()
    val isLost = itemType != "found"
    val isEdit = itemType == "edit"

    // ── 表單狀態 ──
    var title by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var color by remember { mutableStateOf("") }
    var locationName by remember { mutableStateOf("") }
    var latitude by remember { mutableStateOf(Constants.DEFAULT_LATITUDE) }
    var longitude by remember { mutableStateOf(Constants.DEFAULT_LONGITUDE) }
    var lostAt by remember { mutableStateOf(System.currentTimeMillis()) }
    var rewardText by remember { mutableStateOf("") }
    var hasReward by remember { mutableStateOf(false) }
    var storageLocation by remember { mutableStateOf("") }
    var handedToPolice by remember { mutableStateOf(false) }
    var imageUris by remember { mutableStateOf<List<Uri>>(emptyList()) }

    // ── UI 控制狀態 ──
    var categoryExpanded by remember { mutableStateOf(false) }
    var colorExpanded by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }
    var showLocationPicker by remember { mutableStateOf(false) }

    val datePickerState = rememberDatePickerState(initialSelectedDateMillis = lostAt)
    val timePickerState = rememberTimePickerState(
        initialHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY),
        initialMinute = Calendar.getInstance().get(Calendar.MINUTE)
    )
    val locationSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // 編輯模式載入資料
    LaunchedEffect(editItemId) {
        if (editItemId != null) itemViewModel.loadItemForEdit(editItemId)
    }
    LaunchedEffect(addState.editItem) {
        addState.editItem?.let { item ->
            title = item.title
            category = item.category
            description = item.description
            color = item.color
            locationName = item.locationName
            latitude = item.latitude
            longitude = item.longitude
            lostAt = item.lostAt
            rewardText = if (item.reward > 0) item.reward.toString() else ""
            hasReward = item.hasReward
            storageLocation = item.storageLocation
            handedToPolice = item.handedToPolice
            imageUris = item.images.mapNotNull { url ->
                runCatching { Uri.parse(url) }.getOrNull()
            }
        }
    }

    // 成功後導航
    LaunchedEffect(addState.successItemId) {
        addState.successItemId?.let { id ->
            onSubmitSuccess(id)
            itemViewModel.clearAddState()
        }
    }

    val screenTitle = when {
        isEdit -> "編輯物品"
        isLost -> "登記遺失物"
        else -> "登記撿到物"
    }
    val accentColor = if (isLost) FounditOrange else FounditGreen

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(screenTitle, color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = accentColor)
            )
        }
    ) { padding ->
        if (addState.isLoading) {
            LoadingOverlay()
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {

                // ── 相片選取 ──
                ImagePickerRow(
                    images = imageUris,
                    onImagesChanged = { imageUris = it }
                )

                // ── 物品名稱 ──
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("物品名稱 *") },
                    placeholder = { Text("例如：黑色皮夾、iPhone 15") },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth()
                )

                // ── 分類選單 ──
                ExposedDropdownMenuBox(
                    expanded = categoryExpanded,
                    onExpandedChange = { categoryExpanded = it }
                ) {
                    OutlinedTextField(
                        value = category,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("分類 *") },
                        placeholder = { Text("請選擇分類") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    )
                    ExposedDropdownMenu(
                        expanded = categoryExpanded,
                        onDismissRequest = { categoryExpanded = false }
                    ) {
                        Constants.ITEM_CATEGORIES.forEach { cat ->
                            DropdownMenuItem(
                                text = { Text(cat) },
                                onClick = { category = cat; categoryExpanded = false }
                            )
                        }
                    }
                }

                // ── 顏色選單 ──
                ExposedDropdownMenuBox(
                    expanded = colorExpanded,
                    onExpandedChange = { colorExpanded = it }
                ) {
                    OutlinedTextField(
                        value = color,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("顏色") },
                        placeholder = { Text("請選擇顏色") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = colorExpanded) },
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    )
                    ExposedDropdownMenu(
                        expanded = colorExpanded,
                        onDismissRequest = { colorExpanded = false }
                    ) {
                        Constants.ITEM_COLORS.forEach { c ->
                            DropdownMenuItem(
                                text = { Text(c) },
                                onClick = { color = c; colorExpanded = false }
                            )
                        }
                    }
                }

                // ── 詳細描述 ──
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("詳細描述") },
                    placeholder = { Text("請描述物品特徵，方便辨識") },
                    minLines = 3,
                    maxLines = 6,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth()
                )

                // ── 地點選擇 ──
                OutlinedTextField(
                    value = if (locationName.isNotBlank()) locationName else "",
                    onValueChange = { locationName = it },
                    label = { Text(if (isLost) "遺失地點 *" else "撿到地點 *") },
                    placeholder = { Text("點擊右側圖示在地圖選取") },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    trailingIcon = {
                        IconButton(onClick = { showLocationPicker = true }) {
                            Icon(
                                Icons.Filled.LocationOn,
                                contentDescription = "選擇地點",
                                tint = accentColor
                            )
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                // ── 日期時間選擇 ──
                OutlinedTextField(
                    value = lostAt.toDateString("yyyy/MM/dd HH:mm"),
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(if (isLost) "遺失時間 *" else "撿到時間 *") },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    trailingIcon = {
                        IconButton(onClick = { showDatePicker = true }) {
                            Icon(
                                Icons.Filled.CalendarMonth,
                                contentDescription = "選擇日期",
                                tint = accentColor
                            )
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showDatePicker = true }
                )

                // ── 撿到物額外欄位 ──
                if (!isLost) {
                    OutlinedTextField(
                        value = storageLocation,
                        onValueChange = { storageLocation = it },
                        label = { Text("存放地點") },
                        placeholder = { Text("物品目前存放在哪裡？") },
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("已移交警察局", style = MaterialTheme.typography.bodyMedium)
                        Switch(checked = handedToPolice, onCheckedChange = { handedToPolice = it })
                    }
                }

                // ── 遺失物懸賞 ──
                if (isLost) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("提供懸賞金額", style = MaterialTheme.typography.bodyMedium)
                        Switch(checked = hasReward, onCheckedChange = { hasReward = it })
                    }
                    if (hasReward) {
                        OutlinedTextField(
                            value = rewardText,
                            onValueChange = { rewardText = it.filter { c -> c.isDigit() } },
                            label = { Text("懸賞金額（NT\$）") },
                            singleLine = true,
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                Spacer(Modifier.height(8.dp))

                // ── 發布按鈕 ──
                Button(
                    onClick = {
                        if (isEdit && editItemId != null) {
                            val type = addState.editItem?.type
                                ?: if (isLost) ItemType.LOST else ItemType.FOUND
                            itemViewModel.updateItem(
                                itemId = editItemId,
                                type = type,
                                title = title,
                                category = category,
                                description = description,
                                color = color,
                                imageUris = imageUris,
                                latitude = latitude,
                                longitude = longitude,
                                locationName = locationName,
                                lostAt = lostAt,
                                reward = rewardText.toIntOrNull() ?: 0,
                                hasReward = hasReward,
                                storageLocation = storageLocation,
                                handedToPolice = handedToPolice
                            )
                        } else {
                            val type = if (isLost) ItemType.LOST else ItemType.FOUND
                            itemViewModel.createItem(
                                type = type,
                                title = title,
                                category = category,
                                description = description,
                                color = color,
                                imageUris = imageUris,
                                latitude = latitude,
                                longitude = longitude,
                                locationName = locationName,
                                lostAt = lostAt,
                                reward = rewardText.toIntOrNull() ?: 0,
                                hasReward = hasReward,
                                storageLocation = storageLocation,
                                handedToPolice = handedToPolice
                            )
                        }
                    },
                    enabled = title.isNotBlank() && category.isNotBlank() && locationName.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = accentColor)
                ) {
                    Text(
                        text = if (isEdit) "儲存修改" else "發布",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(Modifier.height(16.dp))
            }
        }

        ErrorSnackbar(
            message = addState.errorMessage,
            onDismiss = { itemViewModel.clearAddState() }
        )
    }

    // ── 日期選擇器 ──
    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val cal = Calendar.getInstance().apply { timeInMillis = lostAt }
                        val dateCal = Calendar.getInstance().apply { timeInMillis = millis }
                        cal.set(Calendar.YEAR, dateCal.get(Calendar.YEAR))
                        cal.set(Calendar.MONTH, dateCal.get(Calendar.MONTH))
                        cal.set(Calendar.DAY_OF_MONTH, dateCal.get(Calendar.DAY_OF_MONTH))
                        lostAt = cal.timeInMillis
                    }
                    showDatePicker = false
                    showTimePicker = true
                }) { Text("下一步") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("取消") }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // ── 時間選擇器 ──
    if (showTimePicker) {
        Dialog(onDismissRequest = { showTimePicker = false }) {
            androidx.compose.material3.Surface(
                shape = RoundedCornerShape(16.dp),
                tonalElevation = 6.dp
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "選擇時間",
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.padding(bottom = 20.dp)
                    )
                    TimePicker(state = timePickerState)
                    Spacer(Modifier.height(16.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showTimePicker = false }) { Text("取消") }
                        TextButton(onClick = {
                            val cal = Calendar.getInstance().apply { timeInMillis = lostAt }
                            cal.set(Calendar.HOUR_OF_DAY, timePickerState.hour)
                            cal.set(Calendar.MINUTE, timePickerState.minute)
                            lostAt = cal.timeInMillis
                            showTimePicker = false
                        }) { Text("確認") }
                    }
                }
            }
        }
    }

    // ── 地點選擇器 ──
    if (showLocationPicker) {
        ModalBottomSheet(
            onDismissRequest = { showLocationPicker = false },
            sheetState = locationSheetState
        ) {
            LocationPickerSheet(
                initialLat = latitude,
                initialLng = longitude,
                initialName = locationName,
                onConfirm = { lat, lng, name ->
                    latitude = lat
                    longitude = lng
                    locationName = name
                    showLocationPicker = false
                },
                onDismiss = { showLocationPicker = false }
            )
        }
    }
}
