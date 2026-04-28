package com.example.foundit.ui.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.example.foundit.data.model.Item
import com.example.foundit.data.model.ItemType
import com.example.foundit.ui.theme.FounditGreen
import com.example.foundit.ui.theme.FounditOrange
import com.example.foundit.ui.theme.FounditYellow

/** 物品列表卡片 */
@Composable
fun ItemCard(
    item: Item,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            // 物品圖片
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center
            ) {
                if (item.images.isNotEmpty()) {
                    AsyncImage(
                        model = item.images.first(),
                        contentDescription = item.title,
                        modifier = Modifier.size(80.dp).clip(RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = getCategoryEmoji(item.category),
                        style = MaterialTheme.typography.headlineMedium
                    )
                }
            }

            Spacer(modifier = Modifier.width(12.dp))

            // 物品資訊
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // 遺失/撿到標籤
                    Box(
                        modifier = Modifier
                            .background(
                                color = if (item.type == ItemType.LOST) FounditOrange.copy(alpha = 0.15f)
                                else FounditGreen.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(4.dp)
                            )
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = item.type.label,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (item.type == ItemType.LOST) FounditOrange else FounditGreen,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    // 賞金標示
                    if (item.hasReward && item.reward > 0) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Filled.Star,
                                contentDescription = "賞金",
                                tint = FounditYellow,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = item.reward.toCurrencyString(),
                                style = MaterialTheme.typography.labelSmall,
                                color = FounditYellow,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                // 物品標題
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp)
                )

                // 分類
                Text(
                    text = item.category,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(6.dp))

                // 地點 & 時間
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(
                        imageVector = Icons.Filled.LocationOn,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = item.locationName.ifBlank { "未知地點" },
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 2.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = Icons.Filled.Schedule,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = item.lostAt.toRelativeTime(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 2.dp)
                    )
                }
            }
        }
    }
}

/** 根據分類取得 Emoji 圖示 */
fun getCategoryEmoji(category: String): String = when {
    category.contains("錢包") || category.contains("皮夾") -> "👛"
    category.contains("手機") || category.contains("平板") -> "📱"
    category.contains("鑰匙") -> "🔑"
    category.contains("文件") || category.contains("證件") -> "📄"
    category.contains("包包") || category.contains("背包") -> "🎒"
    category.contains("眼鏡") -> "👓"
    category.contains("首飾") || category.contains("飾品") -> "💎"
    category.contains("服飾") -> "👔"
    category.contains("電子") -> "💻"
    category.contains("寵物") -> "🐾"
    category.contains("交通") -> "🚗"
    else -> "📦"
}

fun Int.toCurrencyString(): String = "NT\$ %,d".format(this)
fun Long.toRelativeTime(): String {
    val diff = System.currentTimeMillis() - this
    return when {
        diff < 60_000L -> "剛剛"
        diff < 3_600_000L -> "${diff / 60_000} 分鐘前"
        diff < 86_400_000L -> "${diff / 3_600_000} 小時前"
        diff < 604_800_000L -> "${diff / 86_400_000} 天前"
        else -> {
            val d = java.util.Date(this)
            val sdf = java.text.SimpleDateFormat("MM/dd", java.util.Locale.TAIWAN)
            sdf.format(d)
        }
    }
}
