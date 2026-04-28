import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/qr_item.dart';
import '../../providers/core_providers.dart';
import '../../providers/qr_provider.dart';
import '../../widgets/gradient_button.dart';

/// QR 防丟標籤頁 — 接後端 `/qr/items`、`/qr/generate`、`/qr/items/:id`
class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            _TabRow(selected: _tab, onTap: (i) => setState(() => _tab = i)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _tab == 0 ? const _MyTags() : const _HowItWorks(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _OutlineBtn(
                      icon: Icons.qr_code_scanner_rounded,
                      label: '掃描 QR',
                      onTap: () => context.push('/qr/scan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: '建立標籤',
                      icon: Icons.add_rounded,
                      onPressed: () => _showCreateSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTagSheet(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'QR 防丟標籤',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const tabs = ['我的標籤', '使用方式'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.allRound,
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.surface : Colors.transparent,
                  borderRadius: AppRadius.allRound,
                  boxShadow: sel ? AppShadows.xs : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MyTags extends ConsumerWidget {
  const _MyTags();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myQrItemsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myQrItemsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('讀取失敗',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                _EmptyHint(),
              ],
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (_, i) => _TagCard(tag: items[i]),
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: const [
            Icon(Icons.qr_code_2_rounded,
                size: 48, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              '還沒建立任何 QR 標籤',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              '點擊下方「建立標籤」為貴重物品產生防丟 QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagCard extends ConsumerWidget {
  const _TagCard({required this.tag});
  final QrItemModel tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('M/d', 'zh_TW');
    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.allLg,
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: AppRadius.allMd,
                ),
                child: QrImageView(
                  data: tag.qrCode,
                  version: QrVersions.auto,
                  size: double.infinity,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primary700,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.primary700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '建立：${fmt.format(tag.createdAt)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除標籤'),
        content: Text('確定要刪除「${tag.name}」嗎？此動作不可復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(qrRepositoryProvider).remove(tag.id);
      ref.invalidate(myQrItemsProvider);
      if (context.mounted) {
        AppSnackbar.success(context, '已刪除');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, '刪除失敗：$e');
      }
    }
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepCard(
            n: '01',
            title: '建立專屬 QR 標籤',
            desc: '為貴重物品產生一個不公開資訊的 QR，可列印貼在物品上。',
            gradient: AppColors.primaryGradient,
          ),
          const SizedBox(height: 12),
          _StepCard(
            n: '02',
            title: '好心人掃描 QR',
            desc: '撿到者掃描後會看到您設定的聯絡方式，無法看到您真實手機。',
            gradient: AppColors.mintGradient,
          ),
          const SizedBox(height: 12),
          _StepCard(
            n: '03',
            title: '透過找得到聯繫',
            desc: '雙方使用 App 內加密聊天溝通，保護隱私。',
            gradient: AppColors.rewardGradient,
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.n,
    required this.title,
    required this.desc,
    required this.gradient,
  });
  final String n;
  final String title;
  final String desc;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppRadius.allMd,
            ),
            alignment: Alignment.center,
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateTagSheet extends ConsumerStatefulWidget {
  const _CreateTagSheet();

  @override
  ConsumerState<_CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<_CreateTagSheet> {
  final _ctrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.warning(context, '請先輸入物品名稱');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(qrRepositoryProvider).generate(
            name: name,
            description: _descCtrl.text.trim(),
          );
      ref.invalidate(myQrItemsProvider);
      if (mounted) {
        AppSnackbar.success(context, '標籤建立成功');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, '建立失敗：$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.topXl,
        ),
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
            Text('新增 QR 標籤',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              '為物品命名方便辨識（不會公開）',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: '例：我的筆電、背包…',
                labelText: '物品名稱',
              ),
            ),
            TextField(
              controller: _descCtrl,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '例：黑色，鍵盤旁有貼紙',
                labelText: '備註（選填）',
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: _saving ? '建立中…' : '產生 QR 碼',
              icon: Icons.qr_code_rounded,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
