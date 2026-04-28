import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/user_provider.dart';
import '../../widgets/gradient_button.dart';

/// SharedPreferences 中與「偏好」相關的 key（純前端、不送 server）
const String _prefLocationVisible = 'pref_location_visible';
const String _prefVerifiedBadgeVisible = 'pref_verified_badge_visible';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  late SharedPreferences _prefs;

  /// avatar 顯示用：本地剛挑的 file > 已上傳的 URL
  File? _localAvatar;
  String _avatarUrl = '';
  String _initialName = '';
  String _initialBio = '';
  String _initialAvatar = '';

  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _initialized = false;

  bool _locationVisible = true;
  bool _verifiedBadgeVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    _prefs = ref.read(sharedPreferencesProvider);
    _locationVisible = _prefs.getBool(_prefLocationVisible) ?? true;
    _verifiedBadgeVisible =
        _prefs.getBool(_prefVerifiedBadgeVisible) ?? true;

    final cached = ref.read(authProvider).user;
    if (cached != null) _applyUser(cached);

    // 重新從 backend 拉一份權威資料
    await ref.read(authProvider.notifier).refresh();
    final fresh = ref.read(authProvider).user;
    if (fresh != null) _applyUser(fresh);
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  void _applyUser(dynamic u) {
    _nameCtrl.text = u.name as String? ?? '';
    _bioCtrl.text = u.bio as String? ?? '';
    _avatarUrl = u.avatarUrl as String? ?? '';
    _initialName = u.name as String? ?? '';
    _initialBio = u.bio as String? ?? '';
    _initialAvatar = u.avatarUrl as String? ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameCtrl.text.trim() != _initialName ||
      _bioCtrl.text.trim() != _initialBio ||
      _avatarUrl != _initialAvatar;

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (file == null) return;
    if (!mounted) return;

    setState(() {
      _localAvatar = File(file.path);
      _uploadingAvatar = true;
    });

    final url = await ref
        .read(uploadRepositoryProvider)
        .uploadImage(File(file.path));

    if (!mounted) return;
    setState(() {
      _uploadingAvatar = false;
      if (url != null && url.isNotEmpty) {
        _avatarUrl = url;
      } else {
        _localAvatar = null;
        AppSnackbar.error(context, '頭像上傳失敗，請稍後再試');
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.warning(context, '顯示名稱不能空白');
      return;
    }
    if (name.length > 50) {
      AppSnackbar.warning(context, '顯示名稱請控制在 50 字以內');
      return;
    }
    if (bio.length > 500) {
      AppSnackbar.warning(context, '自我介紹請控制在 500 字以內');
      return;
    }
    if (_uploadingAvatar) {
      AppSnackbar.warning(context, '頭像還在上傳，請稍候');
      return;
    }
    if (!_hasChanges) {
      AppSnackbar.info(context, '沒有變更需要儲存');
      return;
    }

    setState(() => _saving = true);

    // 將前端偏好寫入 SharedPreferences（不送 server）
    await _prefs.setBool(_prefLocationVisible, _locationVisible);
    await _prefs.setBool(_prefVerifiedBadgeVisible, _verifiedBadgeVisible);

    final ok = await ref.read(authProvider.notifier).updateProfile(
          name: name == _initialName ? null : name,
          bio: bio == _initialBio ? null : bio,
          avatarUrl: _avatarUrl == _initialAvatar ? null : _avatarUrl,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ref.invalidate(userStatsProvider);
      ref.invalidate(userBadgesProvider);
      AppSnackbar.success(context, '個人檔案已更新');
      context.pop();
    } else {
      final err = ref.read(authProvider).error;
      AppSnackbar.error(context, '儲存失敗：${err ?? '請稍後再試'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authProvider).user != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => context.pop()),
            if (!_initialized)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (!isLoggedIn)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        const Text('請先登入才能編輯個人檔案',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('前往登入'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarPicker(
                        url: _avatarUrl,
                        local: _localAvatar,
                        uploading: _uploadingAvatar,
                        onTap: _pickAvatar,
                      ),
                      const SizedBox(height: 28),
                      const _Label('顯示名稱'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          hintText: '輸入名稱',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      const _Label('自我介紹'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bioCtrl,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: '介紹自己…',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_bioCtrl.text.length} / 500',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _Label('聯絡資訊'),
                      const SizedBox(height: 8),
                      _ReadonlyRow(
                        icon: Icons.phone_iphone_rounded,
                        label: '手機',
                        value: _displayPhone(
                          ref.read(authProvider).user?.phone ?? '',
                        ),
                        trailing: ref.read(authProvider).user?.isVerified ==
                                true
                            ? '已驗證'
                            : '未驗證',
                        trailingColor:
                            ref.read(authProvider).user?.isVerified == true
                                ? AppColors.found
                                : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 10),
                      _ReadonlyRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: _displayEmail(
                          ref.read(authProvider).user?.email ?? '',
                        ),
                        trailing: '即將推出',
                        trailingColor: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 28),
                      const _Label('偏好'),
                      const SizedBox(height: 8),
                      _TogglePref(
                        icon: Icons.location_on_rounded,
                        title: '公開我的大致位置',
                        desc: '只會顯示行政區，不會顯示精確地點',
                        value: _locationVisible,
                        onChanged: (v) =>
                            setState(() => _locationVisible = v),
                      ),
                      _TogglePref(
                        icon: Icons.verified_user_rounded,
                        title: '顯示驗證徽章',
                        desc: '讓對方知道你是已驗證用戶',
                        value: _verifiedBadgeVisible,
                        onChanged: (v) =>
                            setState(() => _verifiedBadgeVisible = v),
                      ),
                    ],
                  ),
                ),
              ),
            if (_initialized && isLoggedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: GradientButton(
                  label: _saving ? '儲存中…' : '儲存變更',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _displayPhone(String raw) {
  if (raw.isEmpty) return '尚未綁定';
  // OAuth fake phone（如 g:xxxx 或 google_xxx_xxx）就不要露給使用者看
  if (raw.startsWith('g:') ||
      raw.startsWith('google_') ||
      raw.startsWith('line_') ||
      raw.startsWith('apple_')) {
    return '透過第三方登入';
  }
  return raw;
}

String _displayEmail(String raw) => raw.isEmpty ? '尚未綁定' : raw;

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
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
            child: Text('編輯個人檔案',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.url,
    required this.local,
    required this.uploading,
    required this.onTap,
  });

  final String url;
  final File? local;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (local != null) {
      content = ClipOval(
        child: Image.file(local!,
            width: 104, height: 104, fit: BoxFit.cover),
      );
    } else if (url.isNotEmpty) {
      content = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          placeholder: (_, __) => const _AvatarPlaceholder(),
          errorWidget: (_, __, ___) => const _AvatarPlaceholder(),
        ),
      );
    } else {
      content = const _AvatarPlaceholder();
    }

    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: SizedBox(width: 104, height: 104, child: content),
          ),
          if (uploading)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: uploading ? null : onTap,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded,
          size: 56, color: AppColors.primary300),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  const _ReadonlyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
    required this.trailingColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.allMd,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.allSm,
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color: trailingColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TogglePref extends StatelessWidget {
  const _TogglePref({
    required this.icon,
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: AppRadius.allSm,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 與 add_item_screen 的 _ImageSourceSheet 視覺保持一致
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.allLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              title: '使用相機',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(height: 1),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              title: '從相簿選擇',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
