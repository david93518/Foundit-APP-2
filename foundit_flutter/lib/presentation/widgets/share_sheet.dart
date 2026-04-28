import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/haptics.dart';

Future<void> showShareSheet(
  BuildContext context, {
  required String title,
  required String link,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSheet(title: title, link: link),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.title, required this.link});
  final String title;
  final String link;

  @override
  Widget build(BuildContext context) {
    final items = <_ShareItem>[
      _ShareItem(
        label: 'LINE',
        icon: Icons.chat_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF00C300), Color(0xFF00B100)]),
      ),
      _ShareItem(
        label: '訊息',
        icon: Icons.sms_rounded,
        gradient: AppColors.mintGradient,
      ),
      _ShareItem(
        label: 'Email',
        icon: Icons.mail_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)]),
      ),
      _ShareItem(
        label: 'Facebook',
        icon: Icons.facebook_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF0C63D4)]),
      ),
      _ShareItem(
        label: '系統分享',
        icon: Icons.ios_share_rounded,
        gradient: AppColors.primaryGradient,
      ),
      _ShareItem(
        label: '複製連結',
        icon: Icons.link_rounded,
        gradient: const LinearGradient(
            colors: [Color(0xFF64748B), Color(0xFF475569)]),
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: AppRadius.allRound,
                ),
              ),
            ),
            Text('分享物品', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                )),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (_, i) {
                final it = items[i];
                return GestureDetector(
                  onTap: () {
                    Haptics.light();
                    Navigator.pop(context);
                    if (it.label == '複製連結') {
                      AppSnackbar.success(context, '已複製連結');
                    } else {
                      AppSnackbar.info(context, '分享至 ${it.label}');
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: it.gradient,
                          borderRadius: AppRadius.allMd,
                          boxShadow: AppShadows.sm,
                        ),
                        child: Icon(it.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        it.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ShareItem {
  final String label;
  final IconData icon;
  final Gradient gradient;
  const _ShareItem({
    required this.label,
    required this.icon,
    required this.gradient,
  });
}
