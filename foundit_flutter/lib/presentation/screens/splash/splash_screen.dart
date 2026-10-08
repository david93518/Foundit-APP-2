import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/brand_mark.dart';

/// 啟動畫面：只在讀取本機登入狀態的瞬間出現，導向由路由守衛決定。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 134, child: BrandMark()),
          SizedBox(height: 28),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}
