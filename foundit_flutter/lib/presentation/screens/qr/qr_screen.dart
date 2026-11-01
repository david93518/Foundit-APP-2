import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/qr_tag_image.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/qr_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/qr_provider.dart';

/// 表單關閉時的結果：[tag] 是建立或儲存後的最新資料；[gone] 表示這張防丟牌已不存在（404）。
typedef _SheetResult = ({QrItemModel? tag, bool gone});

/// 伺服器回 404：防丟牌已被移除或不存在。
bool _isGone(Object error) =>
    error is DioException && error.response?.statusCode == 404;

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});
  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  String? _selectedId;
  final Set<String> _deletingIds = {};
  // 已移除的防丟牌：即使重新載入的清單仍帶著（例如後端尚未同步），也不再顯示。
  final Set<String> _removedIds = {};

  Future<void> _refresh() async {
    try {
      ref.invalidate(myQrItemsProvider);
      await ref.read(myQrItemsProvider.future);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '防丟牌暫時無法更新，請稍後再試。');
    }
  }

  Future<_SheetResult?> _openSheet(bool isDemo, {QrItemModel? editing}) =>
      showModalBottomSheet<_SheetResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        constraints: const BoxConstraints(maxWidth: 720),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _CreateTagSheet(isDemo: isDemo, editing: editing),
      );

  Future<void> _create(bool isDemo) async {
    final created = (await _openSheet(isDemo))?.tag;
    if (!mounted || created == null) return;
    setState(() => _selectedId = created.id);
    ref.invalidate(myQrItemsProvider);
    AppSnackbar.success(context, isDemo ? '已新增示範防丟牌' : '防丟牌已建立');
  }

  /// 修改名稱與備註；QR 內容不變，已列印的貼紙照常可用。
  Future<void> _edit(QrItemModel tag, bool isDemo) async {
    final result = await _openSheet(isDemo, editing: tag);
    if (!mounted || result == null) return;
    final updated = result.tag;
    if (result.gone || updated == null) {
      _forget(tag.id);
      ref.invalidate(myQrItemsProvider);
      AppSnackbar.error(context, '這張防丟牌已不存在，清單已重新整理。');
      return;
    }
    // 直接換上伺服器回傳的版本；清單還沒載入時才重新抓。
    if (!ref.read(myQrItemsProvider.notifier).replace(updated)) {
      ref.invalidate(myQrItemsProvider);
    }
    AppSnackbar.success(context, '已儲存變更');
  }

  /// 立刻從畫面拿掉這張防丟牌；正在檢視它的話改回第一張。
  void _forget(String id) {
    ref.read(myQrItemsProvider.notifier).drop(id);
    setState(() {
      _removedIds.add(id);
      if (_selectedId == id) _selectedId = null;
    });
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
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除防丟牌'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(tag.id));
    var removed = false;
    try {
      await ref.read(qrRepositoryProvider).remove(tag.id);
      removed = true;
    } catch (error) {
      // 404 表示這張防丟牌早已不存在，結果與移除相同。
      removed = _isGone(error);
    }
    if (!mounted) return;
    setState(() => _deletingIds.remove(tag.id));
    if (!removed) {
      AppSnackbar.error(context, '未能移除，請稍後再試。');
      return;
    }
    // 先從畫面拿掉，不等重新載入；再向伺服器同步清單。
    _forget(tag.id);
    ref.invalidate(myQrItemsProvider);
    AppSnackbar.success(context, '已移除防丟牌');
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
                          description: '可體驗新增、編輯、切換與移除。示範資料只在本次執行保留，請勿用於實際防丟。',
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
                          data: (all) {
                            final items = [
                              for (final item in all)
                                if (!_removedIds.contains(item.id)) item,
                            ];
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
                                _QrPreview(
                                  tag: selected,
                                  isDemo: isDemo,
                                  onEdit: _deletingIds.contains(selected.id)
                                      ? null
                                      : () => _edit(selected, isDemo),
                                ),
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
  const _QrPreview({required this.tag, required this.isDemo, this.onEdit});
  final QrItemModel tag;
  final bool isDemo;
  final VoidCallback? onEdit;

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
            key: const ValueKey('qr-preview-name'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _TagNote(description: tag.description),
          const SizedBox(height: 6),
          // 建立後仍可修改名稱與備註；QR 內容不變。
          Tooltip(
            message: '編輯防丟牌',
            child: TextButton.icon(
              key: const ValueKey('qr-edit'),
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('編輯名稱與備註'),
            ),
          ),
          const SizedBox(height: 18),
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
                      color: Color(0xFF282B30), // 掃描用，固定深色
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF282B30), // 掃描用，固定深色
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
          if (!isDemo && data.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            _QrActions(key: ValueKey('qr-actions-${tag.id}'), tag: tag),
          ],
        ],
      ),
    );
  }
}

/// 防丟牌的備註（物品特徵）；未填寫時提示可以補上。
class _TagNote extends StatelessWidget {
  const _TagNote({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    final empty = description.trim().isEmpty;
    return Container(
      key: const ValueKey('qr-preview-note'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '備註',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            empty ? '尚未填寫。可以補上顏色、吊飾等特徵，方便辨認。' : description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: empty ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 存成可列印的 PNG，或交給系統分享面板（LINE、AirDrop、列印⋯）。
class _QrActions extends StatefulWidget {
  const _QrActions({super.key, required this.tag});
  final QrItemModel tag;
  @override
  State<_QrActions> createState() => _QrActionsState();
}

class _QrActionsState extends State<_QrActions> {
  final _shareKey = GlobalKey();
  bool _busy = false;

  String get _fileName {
    final id = widget.tag.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return 'foundit-tag-${id.length > 8 ? id.substring(0, 8) : id}';
  }

  Future<Uint8List> _render() =>
      renderQrTagPng(data: widget.tag.qrCode, name: widget.tag.name);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    try {
      final bytes = await _render();
      // 瀏覽器沒有相簿，交給分享（不支援時會直接下載）。
      if (kIsWeb) return await _shareBytes(bytes);
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        if (mounted) {
          AppSnackbar.error(context, '請到系統設定允許 FOUND !T 加入照片，再存一次。');
        }
        return;
      }
      await Gal.putImageBytes(bytes, name: _fileName);
      if (mounted) AppSnackbar.success(context, '已存到相簿，可以直接列印或貼上。');
    } on GalException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        switch (e.type) {
          GalExceptionType.accessDenied => '請到系統設定允許 FOUND !T 加入照片，再存一次。',
          GalExceptionType.notEnoughSpace => '裝置空間不足，請清出空間後再試。',
          _ => '未能存到相簿，請改用「分享」。',
        },
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '未能存到相簿，請改用「分享」。');
    }
  });

  Future<void> _share() => _run(() async {
    try {
      await _shareBytes(await _render());
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '暫時無法分享，請稍後再試。');
    }
  });

  Future<void> _shareBytes(Uint8List bytes) async {
    // iPad 的分享面板需要錨點，否則會直接失敗。
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['$_fileName.png'],
        subject: 'FOUND !T 防丟牌：${widget.tag.name}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('qr-save'),
            onPressed: _busy ? null : _save,
            style: style.merge(
              FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(kIsWeb ? '下載圖片' : '存到相簿'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: _shareKey,
            onPressed: _busy ? null : _share,
            style: style.merge(
              OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: const Text('分享'),
          ),
        ),
      ],
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
                    if (tag.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tag.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

/// 新增防丟牌；帶入 [editing] 時改為編輯名稱與備註（QR 內容不變）。
class _CreateTagSheet extends ConsumerStatefulWidget {
  const _CreateTagSheet({required this.isDemo, this.editing});
  final bool isDemo;
  final QrItemModel? editing;
  @override
  ConsumerState<_CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<_CreateTagSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.editing?.name ?? '');
    _description = TextEditingController(
      text: widget.editing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// 伺服器的 4xx 訊息（例如名稱含電話或 Email）可直接顯示；其他情況給通用說明。
  String _failure(Object error) {
    final status = error is DioException ? error.response?.statusCode ?? 0 : 0;
    final message = apiErrorMessage(error);
    if (status >= 400 && status < 500 && status != 401 && message != null) {
      final reason = message.replaceFirst(RegExp(r'[。.！!]+$'), '');
      return '$reason。你的輸入已保留，修改後再試一次。';
    }
    return _isEdit ? '暫時無法儲存變更。你的輸入已保留，請再試一次。' : '暫時無法建立。你的輸入已保留，請再試一次。';
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final description = _description.text.trim();
    final editing = widget.editing;
    // 沒有修改就直接關閉，不必送出。
    if (editing != null &&
        name == editing.name &&
        description == editing.description) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(qrRepositoryProvider);
    try {
      final item = editing == null
          ? await repository.generate(name: name, description: description)
          : await repository.update(
              editing.id,
              name: name,
              description: description,
            );
      if (editing == null) ref.invalidate(myQrItemsProvider);
      if (mounted) {
        Navigator.pop<_SheetResult>(context, (tag: item, gone: false));
      }
    } catch (error) {
      if (!mounted) return;
      if (editing != null && _isGone(error)) {
        Navigator.pop<_SheetResult>(context, (tag: null, gone: true));
      } else {
        setState(() => _error = _failure(error));
      }
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
                      _isEdit
                          ? '編輯防丟牌'
                          : widget.isDemo
                          ? '新增示範防丟牌'
                          : '新增防丟牌',
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
                _isEdit
                    ? '名稱與備註會顯示在掃描結果中，方便撿到的人確認物品。'
                    : widget.isDemo
                    ? '替物品命名，體驗專屬 QR。示範不會啟用公開認領服務。'
                    : '以物品名稱與特徵，辨認每一張防丟牌。',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 16),
                _Notice(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR 內容不會改變',
                  description: widget.isDemo
                      ? '示範 QR 不受影響。'
                      : '已列印或貼上的防丟牌可以繼續使用，掃描後會顯示新的名稱與備註。',
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('qr-sheet-name'),
                controller: _name,
                autofocus: !_isEdit,
                enabled: !_saving,
                // 編輯時放寬到後端上限，避免截斷既有名稱。
                maxLength: _isEdit ? 100 : 50,
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
                key: const ValueKey('qr-sheet-description'),
                controller: _description,
                enabled: !_saving,
                maxLength: _isEdit ? 500 : 200,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '備註（選填）',
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
                // 表單會蓋住頁面底部的提示列，錯誤直接顯示在表單內。
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
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
                    : Icon(
                        _isEdit ? Icons.check_rounded : Icons.qr_code_rounded,
                        size: 20,
                      ),
                label: Text(
                  _saving
                      ? (_isEdit ? '正在儲存…' : '正在建立…')
                      : _isEdit
                      ? '儲存變更'
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
