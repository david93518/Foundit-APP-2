import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/api/api_client.dart';
import '../../../data/repositories/upload_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.pickAvatar});

  /// Optional picker injection lets embedded clients and tests supply an XFile.
  final Future<XFile?> Function(ImageSource source)? pickAvatar;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _saveFailed = '暫時無法儲存。你的修改已保留，請稍後再試。';

  final _formKey = GlobalKey<FormState>();
  final _errorKey = GlobalKey();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'profile-edit-name');
  final _bioFocus = FocusNode(debugLabel: 'profile-edit-bio');
  String _initialName = '';
  String _initialBio = '';
  String _initialAvatar = '';
  String _avatarUrl = '';
  Uint8List? _avatarBytes;
  String _avatarFilename = 'avatar.jpg';
  String? _avatarMimeType;
  String? _error;
  bool _avatarNeedsUpload = false;
  bool _initialized = false;
  bool _saving = false;
  bool _picking = false;
  bool _allowLeave = false;

  bool get _hasChanges =>
      _name.text.trim() != _initialName ||
      _bio.text.trim() != _initialBio ||
      _avatarNeedsUpload ||
      _avatarUrl != _initialAvatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final user =
        ref.read(authProvider).user ??
        await ref.read(authRepositoryProvider).cachedUser();
    if (!mounted) return;
    if (user != null) {
      _name.text = _initialName = user.name;
      _bio.text = _initialBio = user.bio;
      _avatarUrl = _initialAvatar = user.avatarUrl;
    }
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  /// iOS 的中文鍵盤沒有「收起」鍵；點欄位以外的地方就收起鍵盤。
  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  String get _saveLabel => _saving
      ? '正在儲存…'
      : _error != null
      ? '重試儲存'
      : '儲存變更';

  /// 顯示錯誤並捲到看得見的位置：從頂端的「儲存」送出時，錯誤訊息可能在畫面下方。
  void _fail(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _errorKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<void> _leave() async {
    setState(() => _allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _cancel() async {
    if (_saving || _picking) return;
    if (_hasChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放棄這次修改？'),
          content: const Text('尚未儲存的名稱、介紹與照片將不會更新。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放棄修改'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await _leave();
  }

  Future<void> _pickAvatar() async {
    if (_picking || _saving) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('從相簿選擇'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('拍攝照片'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picker = widget.pickAvatar;
      final file = picker != null
          ? await picker(source)
          : await ImagePicker().pickImage(
              source: source,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 88,
            );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('empty image');
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFilename = file.name.isEmpty ? 'avatar.jpg' : file.name;
        _avatarMimeType = file.mimeType;
        _avatarNeedsUpload = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '無法讀取這張照片，請重新選擇或確認相機與相簿權限。');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !_formKey.currentState!.validate()) return;
    if (!_hasChanges) {
      AppSnackbar.info(context, '沒有需要儲存的變更');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_avatarNeedsUpload) {
        final url = await ref
            .read(uploadRepositoryProvider)
            .uploadImageBytes(
              _avatarBytes!,
              filename: _avatarFilename,
              mimeType: _avatarMimeType,
            );
        if (!mounted) return;
        if (url == null || url.isEmpty) {
          _fail('照片上傳失敗。修改與照片已保留，請重試儲存。');
          return;
        }
        _avatarUrl = url;
        _avatarNeedsUpload = false;
      }
      final ok = await ref
          .read(authProvider.notifier)
          .updateProfile(
            name: _name.text.trim() == _initialName ? null : _name.text.trim(),
            bio: _bio.text.trim() == _initialBio ? null : _bio.text.trim(),
            avatarUrl: _avatarUrl == _initialAvatar ? null : _avatarUrl,
          );
      if (!mounted) return;
      if (!ok) {
        // authProvider 已用 apiErrorMessage 取出伺服器的說明（例如名稱保留給官方），
        // 原樣告訴使用者該怎麼改；沒有說明時才用通用訊息。
        _fail(ref.read(authProvider).error ?? _saveFailed);
        return;
      }
      AppSnackbar.success(context, '個人檔案已更新');
      await _leave();
    } on UploadRejected catch (e) {
      if (mounted) _fail(e.message);
    } catch (e) {
      if (mounted) _fail(apiErrorMessage(e) ?? _saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    const fallback = ColoredBox(
      color: AppColors.surfaceSoft,
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.primary,
        size: 36,
      ),
    );
    Uint8List? bytes = _avatarBytes;
    if (bytes == null && _avatarUrl.startsWith('data:image/')) {
      try {
        bytes = base64Decode(_avatarUrl.split(',').last);
      } catch (_) {
        return fallback;
      }
    }
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (_avatarUrl.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: _avatarUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).isLoggedIn;
    final demo = ref.watch(useMockProvider);
    final editing = _initialized && loggedIn;
    final busy = _saving || _picking;
    return PopScope(
      canPop: _allowLeave || (!_hasChanges && !_saving && !_picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        // 鍵盤出現時內容區跟著縮短並可捲動，聚焦的欄位會被捲到鍵盤上方。
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: GestureDetector(
            // 點欄位以外的任何地方（含空白處）都收起鍵盤；欄位與按鈕自己的點擊優先。
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _dismissKeyboard,
            child: Column(
              children: [
                // 標題列固定在頂端，鍵盤開著時「儲存」也一定按得到。
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '取消編輯',
                          onPressed: busy ? null : _cancel,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            '編輯個人檔案',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (editing)
                          // 樣式沿用主題的 TextButton（陶土色、48px 觸控高度）。
                          TextButton(
                            key: const ValueKey('profile-edit-save-bar'),
                            onPressed: busy ? null : _save,
                            child: Text(_saveLabel),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('profile-edit-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: !_initialized
                              ? const Padding(
                                  padding: EdgeInsets.all(36),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : !loggedIn
                              ? _loginPrompt()
                              : _form(demo),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginPrompt() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(
        Icons.person_outline_rounded,
        size: 40,
        color: AppColors.primary,
      ),
      const SizedBox(height: 18),
      const Text(
        '登入後即可編輯個人檔案',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      const Text(
        '在這裡更新你的名稱、照片與介紹。',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () async {
          await context.push('/login');
          if (mounted) await _initialize();
        },
        child: const Text('前往登入'),
      ),
    ],
  );

  Widget _form(bool demo) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipOval(
            child: SizedBox(width: 80, height: 80, child: _avatar()),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            key: const ValueKey('profile-edit-avatar'),
            onPressed: _saving || _picking ? null : _pickAvatar,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_picking ? '正在讀取照片…' : '更換照片'),
          ),
        ),
        if (_avatarNeedsUpload)
          const Text(
            '新照片會在儲存時上傳',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        if (demo) ...[
          const SizedBox(height: 12),
          const Text(
            '體驗模式：變更只保存在此裝置。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 26),
        TextFormField(
          key: const ValueKey('profile-edit-name'),
          controller: _name,
          focusNode: _nameFocus,
          enabled: !_saving,
          maxLength: 50,
          // 鍵盤上的「下一項」直接跳到自我介紹。
          textInputAction: TextInputAction.next,
          onEditingComplete: _bioFocus.requestFocus,
          decoration: const InputDecoration(
            labelText: '顯示名稱',
            hintText: '其他使用者會看到這個名稱',
          ),
          validator: (value) => (value ?? '').trim().isEmpty ? '請填寫顯示名稱' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        // 多行欄位的換行鍵留給換行；收起鍵盤靠點空白處、捲動，或頂端的「儲存」。
        TextFormField(
          key: const ValueKey('profile-edit-bio'),
          controller: _bio,
          focusNode: _bioFocus,
          enabled: !_saving,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '自我介紹（選填）',
            hintText: '簡單介紹自己',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            key: _errorKey,
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('profile-edit-save'),
          onPressed: _saving || _picking ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(_saveLabel),
        ),
      ],
    ),
  );
}
