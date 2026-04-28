package com.example.foundit.ui.component

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.example.foundit.util.Constants
import com.example.foundit.util.GeocodingClient
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import kotlinx.coroutines.launch

/**
 * 地點選取底部表單
 * 使用 Google Maps 讓用戶點擊地圖選擇地點；地點名稱可搭配搜尋（Geocoding）將地圖移到該地址。
 */
@Composable
fun LocationPickerSheet(
    initialLat: Double = Constants.DEFAULT_LATITUDE,
    initialLng: Double = Constants.DEFAULT_LONGITUDE,
    initialName: String = "",
    onConfirm: (lat: Double, lng: Double, name: String) -> Unit,
    onDismiss: () -> Unit
) {
    var selectedLatLng by remember { mutableStateOf(LatLng(initialLat, initialLng)) }
    var locationName by remember { mutableStateOf(initialName) }
    var isGeocoding by remember { mutableStateOf(false) }
    var geocodeError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(initialLat, initialLng),
            Constants.DEFAULT_ZOOM
        )
    }

    fun searchAddressOnMap() {
        if (locationName.isBlank() || isGeocoding) return
        geocodeError = null
        scope.launch {
            isGeocoding = true
            GeocodingClient.geocodeAddress(locationName).fold(
                onSuccess = { hit ->
                    selectedLatLng = hit.latLng
                    cameraPositionState.position =
                        CameraPosition.fromLatLngZoom(hit.latLng, 15f)
                    geocodeError = null
                },
                onFailure = { e ->
                    geocodeError = e.message ?: "查詢失敗"
                },
            )
            isGeocoding = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "選擇地點",
            style = MaterialTheme.typography.titleLarge
        )
        Text(
            text = "可輸入地名後點搜尋，或在地圖上點擊調整位置",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp)
        )

        Spacer(Modifier.height(16.dp))

        // 地圖選點
        GoogleMap(
            modifier = Modifier
                .fillMaxWidth()
                .height(280.dp),
            cameraPositionState = cameraPositionState,
            uiSettings = MapUiSettings(
                zoomControlsEnabled = true,
                myLocationButtonEnabled = false
            ),
            onMapClick = { latLng ->
                selectedLatLng = latLng
            }
        ) {
            Marker(
                state = MarkerState(position = selectedLatLng),
                title = "選擇的地點"
            )
        }

        Spacer(Modifier.height(12.dp))

        // 地點名稱輸入（Geocoding 搜尋）
        OutlinedTextField(
            value = locationName,
            onValueChange = {
                locationName = it
                geocodeError = null
            },
            label = { Text("地點名稱 *") },
            placeholder = { Text("例如：台南火車站、台北101") },
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { searchAddressOnMap() }),
            trailingIcon = {
                if (isGeocoding) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .padding(12.dp)
                            .size(22.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    IconButton(
                        onClick = { searchAddressOnMap() },
                        enabled = locationName.isNotBlank()
                    ) {
                        Icon(Icons.Default.Search, contentDescription = "搜尋並移動地圖")
                    }
                }
            }
        )
        geocodeError?.let { err ->
            Text(
                text = err,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 6.dp)
            )
        }

        Spacer(Modifier.height(16.dp))

        // 按鈕列
        androidx.compose.foundation.layout.Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)
        ) {
            TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) {
                Text("取消")
            }
            Button(
                onClick = {
                    onConfirm(selectedLatLng.latitude, selectedLatLng.longitude, locationName)
                },
                enabled = locationName.isNotBlank(),
                modifier = Modifier.weight(1f)
            ) {
                Text("確認地點")
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}
