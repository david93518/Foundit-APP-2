package com.example.foundit.ui.screen.map

import android.Manifest
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.rememberMultiplePermissionsState
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.tasks.CancellationTokenSource
import com.example.foundit.data.model.ItemType
import com.example.foundit.ui.component.getCategoryEmoji
import com.example.foundit.ui.screen.home.HomeViewModel
import com.example.foundit.ui.theme.FounditBlue
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerInfoWindowContent
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import com.example.foundit.util.Constants

 
@OptIn(ExperimentalMaterial3Api::class, ExperimentalPermissionsApi::class)
@Composable
fun MapScreen(
    onNavigateToItemDetail: (String) -> Unit,
    onNavigateBack: () -> Unit,
    homeViewModel: HomeViewModel
) {
    val uiState by homeViewModel.uiState.collectAsState()
    val context = LocalContext.current
    val locationPermissions = rememberMultiplePermissionsState(
        listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    )
    val fusedLocationClient = remember {
        LocationServices.getFusedLocationProviderClient(context)
    }

    // 預設台北市中心
    val defaultLocation = LatLng(Constants.DEFAULT_LATITUDE, Constants.DEFAULT_LONGITUDE)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(defaultLocation, Constants.DEFAULT_ZOOM)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("地圖搜尋") },
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
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    if (!locationPermissions.allPermissionsGranted) {
                        locationPermissions.launchMultiplePermissionRequest()
                        return@FloatingActionButton
                    }
                    val cts = CancellationTokenSource()
                    fusedLocationClient
                        .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
                        .addOnSuccessListener { loc ->
                            if (loc != null) {
                                val latLng = LatLng(loc.latitude, loc.longitude)
                                cameraPositionState.position =
                                    CameraPosition.fromLatLngZoom(latLng, 15f)
                            }
                        }
                },
                containerColor = FounditBlue,
                contentColor = Color.White
            ) {
                Icon(Icons.Filled.MyLocation, "我的位置")
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                properties = MapProperties(isMyLocationEnabled = locationPermissions.allPermissionsGranted),
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = true,
                    myLocationButtonEnabled = false
                )
            ) {
                // 在地圖上標示所有物品
                uiState.items
                    .filter { it.latitude != 0.0 && it.longitude != 0.0 }
                    .forEach { item ->
                        val position = LatLng(item.latitude, item.longitude)
                        val markerColor = if (item.type == ItemType.LOST)
                            BitmapDescriptorFactory.HUE_ORANGE
                        else
                            BitmapDescriptorFactory.HUE_GREEN

                        MarkerInfoWindowContent(
                            state = MarkerState(position = position),
                            title = item.title,
                            snippet = "${item.type.label} · ${item.locationName}",
                            icon = BitmapDescriptorFactory.defaultMarker(markerColor),
                            onInfoWindowClick = { onNavigateToItemDetail(item.id) }
                        ) {
                            Card(
                                modifier = Modifier.padding(4.dp),
                                shape = RoundedCornerShape(8.dp),
                                elevation = CardDefaults.cardElevation(4.dp)
                            ) {
                                Column(modifier = Modifier.padding(8.dp)) {
                                    Text(
                                        text = "${getCategoryEmoji(item.category)} ${item.title}",
                                        style = MaterialTheme.typography.titleSmall,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = item.type.label,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = if (item.type == ItemType.LOST) FounditOrange else FounditGreen
                                    )
                                    Text(
                                        text = item.locationName,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
            }

            // 統計資訊卡片
            Card(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                val lostCount = uiState.items.count { it.type == ItemType.LOST }
                val foundCount = uiState.items.count { it.type == ItemType.FOUND }
                Text(
                    text = "附近：遺失物 $lostCount 件 · 撿到物 $foundCount 件",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
