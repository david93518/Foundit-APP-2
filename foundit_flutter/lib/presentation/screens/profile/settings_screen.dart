import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/google_account_button.dart';

/// Only settings backed by implemented behavior are presented as controls.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _clearSearches() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(AppConstants.prefRecentSearches);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('此裝置的搜尋紀錄已清除。')));
  }

  Future<void> _deleteAccount() async {
    final phone = ref.read(authProvider).user?.phone ?? '';
    if (phone.startsWith('g:') || phone.startsWith('google_')) {
      await _deleteGoogleAccount();
      return;
    }
    if (!phone.startsWith('09')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('這個登入方式還沒有可用來確認刪除的手機號碼。')));
      return;
    }
    final send = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('刪除帳號'),
        content: const Text(
          '我們會寄送驗證碼到你的手機。確認後，刊登會從公開頁面移除，聊天訊息會匿名化，而且這個帳號不能再登入。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('寄送驗證碼'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    setState(() => _busy = true);
    final sent = await ref.read(authProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!sent) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('驗證碼沒有寄出，帳號尚未刪除。')));
      return;
    }
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('輸入驗證碼'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6 位數驗證碼'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    final otp = code.text.trim();
    code.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).deleteAccount(otp);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isEmpty ? '帳號尚未刪除。' : result.message),
        ),
      );
      return;
    }
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/profile');
  }

  Future<void> _deleteGoogleAccount() async {
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('刪除帳號'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('確認後，刊登會移除、聊天內容會匿名化。請選擇原本的 Google 帳號確認刪除。'),
            const SizedBox(height: 20),
            GoogleAccountButton(
              onToken: (token) async => Navigator.pop(dialogContext, token),
              onError: (message) =>
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (token == null || !mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authRepositoryProvider)
        .deleteGoogleAccount(token);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/profile');
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('確定登出？'),
        content: const Text('登出後會回到登入頁，需要再次登入才能瀏覽與聯絡對方。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/profile');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('登出未完成，請稍後重試。')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTheme() async {
    final current = ref.read(themeModeProvider);
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '外觀',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            for (final mode in AppThemeMode.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(switch (mode) {
                  AppThemeMode.system => Icons.brightness_auto_outlined,
                  AppThemeMode.light => Icons.light_mode_outlined,
                  AppThemeMode.dark => Icons.dark_mode_outlined,
                }),
                title: Text(mode.label),
                subtitle: mode == AppThemeMode.system
                    ? const Text('依照手機設定自動切換')
                    : null,
                trailing: Icon(
                  current == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.primary,
                ),
                onTap: () => Navigator.pop(c, mode),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }

  void _dataInfo(bool mock) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: const Text('資料與使用說明'),
      content: Text(
        mock
            ? '這是功能體驗版本。刊登、收藏和搜尋紀錄保存在此裝置；示範對話不會傳送給真實使用者。\n\n清除瀏覽器或 App 的資料，也會移除這些本機紀錄。'
            : '刊登的照片、物品描述與地點會公開顯示，請避免填寫完整證件號碼、電話或私人住址。\n\n搜尋紀錄、收藏與未送出的訊息草稿會保存在此裝置。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('我知道了'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mock = ref.watch(useMockProvider);
    final loggedIn = ref.watch(authProvider).isLoggedIn;
    final themeMode = ref.watch(themeModeProvider);
    final recent =
        ref
            .read(sharedPreferencesProvider)
            .getStringList(AppConstants.prefRecentSearches) ??
        [];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/profile'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '設定',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      const _Section('此裝置'),
                      _Panel(
                        children: [
                          const _SettingRow(
                            icon: Icons.language_outlined,
                            title: '介面語言',
                            detail: '繁體中文',
                          ),
                          _SettingRow(
                            icon: switch (themeMode) {
                              AppThemeMode.dark => Icons.dark_mode_outlined,
                              AppThemeMode.light => Icons.light_mode_outlined,
                              AppThemeMode.system =>
                                Icons.brightness_auto_outlined,
                            },
                            title: '外觀',
                            detail: themeMode.label,
                            onTap: _pickTheme,
                          ),
                          _SettingRow(
                            icon: Icons.history_rounded,
                            title: '清除搜尋紀錄',
                            detail: recent.isEmpty
                                ? '目前沒有搜尋紀錄'
                                : '${recent.length} 筆搜尋紀錄',
                            onTap: recent.isEmpty ? null : _clearSearches,
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _Section('關於 FOUND !T'),
                      _Panel(
                        children: [
                          _SettingRow(
                            icon: Icons.info_outline_rounded,
                            title: mock ? '體驗模式' : '帳號模式',
                            detail: mock ? '示範資料不會傳送給其他使用者' : '透過登入帳號發布與聯絡',
                          ),
                          _SettingRow(
                            icon: Icons.privacy_tip_outlined,
                            title: '資料與使用說明',
                            onTap: () => _dataInfo(mock),
                          ),
                          const _SettingRow(
                            icon: Icons.tag_rounded,
                            title: '版本',
                            detail: '1.0.0',
                          ),
                        ],
                      ),
                      if (!mock && loggedIn) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _deleteAccount,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('刪除帳號'),
                        ),
                      ],
                      if (!mock) ...[
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : loggedIn
                              ? _logout
                              : () => context.push('/login'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                          icon: Icon(
                            loggedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                          ),
                          label: Text(
                            _busy
                                ? '處理中…'
                                : loggedIn
                                ? '登出帳號'
                                : '登入帳號',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
  );
}

/// 同一組設定放在一張卡裡，列與列之間只用細線。
class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 66),
          children[i],
        ],
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.detail,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.ink50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.ink700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ],
      ),
    ),
  );
}
