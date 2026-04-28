import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

// SharedPreferences 中設定相關的 key（純前端持久化）
const String _prefNotifMatch = 'pref_notif_match';
const String _prefNotifChat = 'pref_notif_chat';
const String _prefNotifMarketing = 'pref_notif_marketing';
const String _prefDarkMode = 'pref_dark_mode';
const String _prefLanguage = 'pref_language';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _ready = false;

  bool _notifMatch = true;
  bool _notifChat = true;
  bool _notifMarketing = false;
  bool _darkMode = false;
  String _language = '繁體中文';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    _prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _notifMatch = _prefs.getBool(_prefNotifMatch) ?? true;
      _notifChat = _prefs.getBool(_prefNotifChat) ?? true;
      _notifMarketing = _prefs.getBool(_prefNotifMarketing) ?? false;
      _darkMode = _prefs.getBool(_prefDarkMode) ?? false;
      _language = _prefs.getString(_prefLanguage) ?? '繁體中文';
      _ready = true;
    });
  }

  Future<void> _setBool(String key, bool v, void Function() apply) async {
    apply();
    setState(() {});
    await _prefs.setBool(key, v);
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _language = lang);
    await _prefs.setString(_prefLanguage, lang);
    if (mounted) {
      AppSnackbar.info(context, '語言將在下次啟動 App 時生效');
    }
  }

  Future<void> _doLogout() async {
    final confirmed = await _confirm(
      title: '確定登出？',
      desc: '您將需要再次登入才能繼續使用',
      destructive: false,
      okText: '登出',
    );
    if (!confirmed) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  Future<void> _doDeleteAccount() async {
    final confirmed = await _confirm(
      title: '刪除帳號？',
      desc: '此操作不可復原，您的所有資料將永久消失。\n（目前後端尚未開放此功能，僅會清除本機資料並登出）',
      destructive: true,
      okText: '我了解，刪除',
    );
    if (!confirmed) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      AppSnackbar.success(context, '已清除本機資料');
      context.go('/login');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String desc,
    required bool destructive,
    required String okText,
  }) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        title: Text(title),
        content: Text(desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? AppColors.error : AppColors.primary,
            ),
            child: Text(okText),
          ),
        ],
      ),
    );
    return v ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final isLoggedIn = ref.watch(authProvider).user != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const _SectionTitle('通知'),
                  _SectionCard(
                    children: [
                      _SwitchRow(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI 配對提示',
                        desc: '有相似物品時推播通知',
                        value: _notifMatch,
                        onChanged: (v) => _setBool(
                          _prefNotifMatch,
                          v,
                          () => _notifMatch = v,
                        ),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.chat_bubble_rounded,
                        title: '聊天訊息',
                        desc: '接收聊天推播',
                        value: _notifChat,
                        onChanged: (v) =>
                            _setBool(_prefNotifChat, v, () => _notifChat = v),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.campaign_rounded,
                        title: '活動優惠',
                        desc: '接收推廣訊息',
                        value: _notifMarketing,
                        onChanged: (v) => _setBool(
                          _prefNotifMarketing,
                          v,
                          () => _notifMarketing = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('外觀'),
                  _SectionCard(
                    children: [
                      _SwitchRow(
                        icon: Icons.dark_mode_rounded,
                        title: '深色模式',
                        desc: '跟隨系統或強制開啟',
                        value: _darkMode,
                        onChanged: (v) {
                          _setBool(_prefDarkMode, v, () => _darkMode = v);
                          AppSnackbar.info(
                              context, '深色模式將在下次啟動時套用');
                        },
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.language_rounded,
                        title: '語言',
                        value: _language,
                        onTap: _showLanguageSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('帳號與安全'),
                  _SectionCard(
                    children: [
                      _ArrowRow(
                        icon: Icons.key_rounded,
                        title: '更換手機號碼',
                        onTap: () => AppSnackbar.info(
                            context, '此功能即將推出，請先聯絡客服'),
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.shield_rounded,
                        title: '隱私設定',
                        onTap: () => AppSnackbar.info(
                            context, '請至「編輯個人檔案 → 偏好」設定'),
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.block_rounded,
                        title: '黑名單',
                        onTap: () =>
                            AppSnackbar.info(context, '黑名單功能即將推出'),
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.download_rounded,
                        title: '下載我的資料',
                        onTap: () =>
                            AppSnackbar.info(context, '資料匯出功能即將推出'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('關於'),
                  _SectionCard(
                    children: [
                      _ArrowRow(
                        icon: Icons.description_rounded,
                        title: '服務條款',
                        onTap: () => _showLegal(
                          title: '服務條款',
                          body:
                              '歡迎使用「找得到」（以下稱本服務）。\n\n'
                              '1. 本服務協助使用者張貼與搜尋遺失或撿到的物品。\n'
                              '2. 您應確保張貼資料真實、不侵害他人權益。\n'
                              '3. 違反規定者，本服務有權移除內容並停權。\n'
                              '4. 完整條款請見官方網站。',
                        ),
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.privacy_tip_rounded,
                        title: '隱私權政策',
                        onTap: () => _showLegal(
                          title: '隱私權政策',
                          body:
                              '我們重視您的隱私：\n\n'
                              '• 個人資料僅用於提供「找得到」服務。\n'
                              '• 您發布的位置只會以行政區層級公開（依您的偏好設定）。\n'
                              '• 您可隨時於「我的 → 設定 → 下載我的資料」匯出您的紀錄。\n'
                              '• 完整政策請見官方網站。',
                        ),
                      ),
                      _Divider(),
                      _ArrowRow(
                        icon: Icons.info_outline_rounded,
                        title: '版本',
                        value: '1.0.0',
                        onTap: () =>
                            AppSnackbar.info(context, '您已是最新版本'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (isLoggedIn) ...[
                    _DangerButton(
                      label: '登出',
                      icon: Icons.logout_rounded,
                      onTap: _doLogout,
                    ),
                    const SizedBox(height: 12),
                    _DangerButton(
                      label: '刪除帳號',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      onTap: _doDeleteAccount,
                    ),
                  ] else
                    _DangerButton(
                      label: '登入',
                      icon: Icons.login_rounded,
                      onTap: () => context.go('/login'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LangSheet(
        current: _language,
        onPick: (v) {
          Navigator.pop(context);
          _setLanguage(v);
        },
      ),
    );
  }

  void _showLegal({required String title, required String body}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}

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
            child: Text('設定',
                style: Theme.of(context).textTheme.displaySmall),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        boxShadow: AppShadows.xs,
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    this.desc,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: AppRadius.allSm,
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (desc != null)
                  Text(desc!,
                      style: const TextStyle(
                        fontSize: 11,
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

class _ArrowRow extends StatelessWidget {
  const _ArrowRow({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: AppRadius.allSm,
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (value != null) ...[
                Text(value!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    )),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 1,
      color: AppColors.divider,
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            border: Border.all(
              color: destructive
                  ? AppColors.error.withValues(alpha: 0.25)
                  : AppColors.divider,
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
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

class _LangSheet extends StatelessWidget {
  const _LangSheet({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    const langs = ['繁體中文', '简体中文', 'English', '日本語'];
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
      ),
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: langs.map((l) {
            final sel = l == current;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onPick(l),
                borderRadius: AppRadius.allMd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (sel)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
