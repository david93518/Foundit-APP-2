import 'package:flutter/material.dart';

/// 物品分類的圖示。整個 App 只用線性 Material 圖示，不混用 emoji，
/// 這樣分類在首頁、搜尋、刊登與詳情看起來是同一套語言。
IconData categoryIcon(String? category) {
  final key = (category ?? '').split('/').first.trim();
  return switch (key) {
    '' || '全部' => Icons.grid_view_rounded,
    '錢包' => Icons.account_balance_wallet_outlined,
    '手機' => Icons.smartphone_outlined,
    '鑰匙' => Icons.key_rounded,
    '文件' => Icons.badge_outlined,
    '包包' => Icons.work_outline_rounded,
    '眼鏡' => Icons.visibility_outlined,
    '首飾' => Icons.diamond_outlined,
    '服飾' => Icons.checkroom_outlined,
    '電子產品' => Icons.headphones_outlined,
    '寵物' => Icons.pets_outlined,
    '交通工具' => Icons.directions_bike_outlined,
    _ => Icons.inventory_2_outlined,
  };
}
