import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/qr_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/qr_provider.dart';

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});
  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  String? _selectedId;
  final Set<String> _deletingIds = {};

  Future<void> _refresh() async {
    try {
      ref.invalidate(myQrItemsProvider);
      await ref.read(myQrItemsProvider.future);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '防丟牌暫時無法更新，請稍後再試。');
    }
  }

  Future<void> _create(bool isDemo) async {
    final created = await showModalBottomSheet<QrItemModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CreateTagSheet(isDemo: isDemo),
    );
    if (!mounted || created == null) return;
    setState(() => _selectedId = created.id);
    ref.invalidate(myQrItemsProvider);
    AppSnackbar.success(context, isDemo ? '已新增示範防丟牌' : '防丟牌已建立');
  }

  Future<void> _remove(QrItemModel tag, bool isDemo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除這張防丟牌？'),
        content: Text(
          isDemo
              ? '將移除「${tag.name}」的示範紀錄。'
              : '移除「${tag.name}」後，原本的 QR 將無法再辨識這件物品。此操作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除防丟牌'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(tag.id));
    try {
      await ref.read(qrRepositoryProvider).remove(tag.id);
      ref.invalidate(myQrItemsProvider);
      if (mounted) {
        if (_selectedId == tag.id) setState(() => _selectedId = null);
        AppSnackbar.success(context, '已移除防丟牌');
      }
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '未能移除，請稍後再試。');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(tag.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(useMockProvider);
    final canManage = isDemo || ref.watch(authProvider).isLoggedIn;
    final itemsAsync = canManage ? ref.watch(myQrItemsProvider) : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'QR 防丟牌',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          if (canManage && !isDemo)
            IconButton(
              tooltip: '掃描防丟牌',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () => context.push('/qr/scan'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: canManage ? _refresh : () async {},
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '讓重逢，多一個可能',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '為重要的物品，\n留一條回家的路。',
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '替隨身物品建立專屬 QR，\n把容易忘記的小東西，好好放在心上。',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (isDemo) ...[
                        const _Notice(
                          icon: Icons.visibility_outlined,
                          title: '示範 QR，尚未連結公開認領服務',
                          description: '可體驗新增、切換與移除。示範資料只在本次執行保留，請勿用於實際防丟。',
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!canManage)
                        _EmptyCard(
                          title: '登入後，管理你的防丟牌',
                          description: '每張防丟牌都需要綁定帳號，\n讓你能隨時查看與管理。',
                          actionLabel: '登入帳號',
                          onAction: () => context.push('/login'),
                        )
                      else
                        itemsAsync!.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(56),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          error: (_, __) => _EmptyCard(
                            title: '防丟牌暫時載入不了',
                            description: '請確認網路連線，再試一次。',
                            actionLabel: '重新載入',
                            onAction: () => ref.invalidate(myQrItemsProvider),
                          ),
                          data: (items) {
                            if (items.isEmpty) {
                              return _EmptyCard(
                                title: '從一件重要的小物開始',
                                description: '鑰匙、背包、雨傘⋯\n替常帶出門的物品，建立第一張防丟牌。',
                                actionLabel: isDemo ? '新增示範防丟牌' : '新增防丟牌',
                                onAction: () => _create(isDemo),
                              );
                            }
                            final selected =
                                items
                                    .where((item) => item.id == _selectedId)
                                    .firstOrNull ??
                                items.first;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _QrPreview(tag: selected, isDemo: isDemo),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '我的防丟牌 · ${items.length}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _create(isDemo),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 19,
                                      ),
                                      label: const Text('新增'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (final tag in items) ...[
                                  _TagRow(
                                    tag: tag,
                                    selected: tag.id == selected.id,
                                    busy: _deletingIds.contains(tag.id),
                                    onSelect: () =>
                                        setState(() => _selectedId = tag.id),
                                    onDelete: () => _remove(tag, isDemo),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 28),
                      const _Notice(
                        icon: Icons.info_outline_rounded,
                        title: '簡單命名，就夠了',
                        description: '名稱與備註可能出現在掃描結果中。只填物品特徵，不需要留下地址、電話或驗證碼。',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.tag, required this.isDemo});
  final QrItemModel tag;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    // A demo encodes a readable disclaimer, never the mock repository's localhost URL.
    final data = isDemo ? 'FOUND !T：示範 QR，尚未連結公開認領服務。' : tag.qrCode;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(
            isDemo ? '示範防丟牌' : '我的專屬防丟牌',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tag.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          if (data.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '這張防丟牌尚未提供 QR 內容。',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 216),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    padding: const EdgeInsets.all(8),
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.textPrimary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 22),
          Text(
            isDemo ? '僅供介面體驗，無法聯絡物主。' : '請先使用 FOUND !T 的掃描功能，\n確認可辨識這張防丟牌。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          if (tag.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              tag.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onDelete,
  });
  final QrItemModel tag;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary50 : AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      selected: selected,
      child: InkWell(
        onTap: busy ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_outline_rounded
                    : Icons.qr_code_rounded,
                color: AppColors.primary,
                size: 25,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('yyyy.MM.dd').format(tag.createdAt)} 建立',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: '移除 ${tag.name}',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 21,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            size: 42,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

class _CreateTagSheet extends ConsumerStatefulWidget {
  const _CreateTagSheet({required this.isDemo});
  final bool isDemo;
  @override
  ConsumerState<_CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<_CreateTagSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final item = await ref
          .read(qrRepositoryProvider)
          .generate(
            name: _name.text.trim(),
            description: _description.text.trim(),
          );
      ref.invalidate(myQrItemsProvider);
      if (mounted) Navigator.pop(context, item);
    } catch (_) {
      if (mounted) setState(() => _error = '暫時無法建立。你的輸入已保留，請再試一次。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isDemo ? '新增示範防丟牌' : '新增防丟牌',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.isDemo
                    ? '替物品命名，體驗專屬 QR。示範不會啟用公開認領服務。'
                    : '以物品名稱與特徵，辨認每一張防丟牌。',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_saving,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? '請輸入物品名稱' : null,
                decoration: const InputDecoration(
                  labelText: '物品名稱',
                  hintText: '例如：每天帶的帆布袋',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                enabled: !_saving,
                maxLength: 200,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '物品特徵（選填）',
                  hintText: '例如：米色，提把有一枚綠色吊飾',
                ),
              ),
              const Text(
                '請勿填寫地址、電話或其他私人資訊。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.qr_code_rounded, size: 20),
                label: Text(
                  _saving
                      ? '正在建立…'
                      : widget.isDemo
                      ? '建立示範 QR'
                      : '建立 QR 防丟牌',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
