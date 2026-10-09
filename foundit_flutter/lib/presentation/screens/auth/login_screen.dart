import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/foundit_ui.dart';
import '../../widgets/google_account_button.dart';
import '../../widgets/invited_account_dialog.dart';

/// App 入口：未登入時一律先停在這裡，登入成功後由路由守衛帶到首頁。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _phoneOpen = false;
  String? _error;

  String get _normalizedPhone {
    var value = _phone.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('+886')) {
      value = '0${value.substring(4)}';
    } else if (value.startsWith('886')) {
      value = '0${value.substring(3)}';
    }
    return value;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _done() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/home');
    }
  }

  Future<void> _google(String token) async {
    setState(() => _error = null);
    final ok = await ref
        .read(authProvider.notifier)
        .oauthLogin(provider: 'google', token: token);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '目前無法登入，請確認網路後再試一次。');
      return;
    }
    _done();
  }

  Future<void> _sendOtp() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final phone = _normalizedPhone;
    _phone.text = phone;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref.read(authProvider.notifier).sendOtp(phone);
      if (!mounted) return;
      if (!sent) {
        setState(() => _error = '暫時無法取得驗證碼，請確認連線後再試一次。');
        return;
      }
      final verified = await context.push<bool>('/otp', extra: phone);
      if (verified == true) _done();
    } catch (_) {
      if (mounted) setState(() => _error = '目前無法連線，請稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invited() async {
    // Update global auth only after the dialog closes, so the route guard
    // cannot replace the login route while its dialog is still open.
    final repository = ref.read(authRepositoryProvider);
    AuthResult? session;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvitedAccountDialog(
        onSubmit: (username, password) async {
          final result = await repository.invitedLogin(username, password);
          if (result.success) session = result;
          return result.success ? null : result.message;
        },
      ),
    );
    if (ok != true || !mounted) return;
    if (session == null) return;
    ref.read(authProvider.notifier).acceptSession(session!);
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final mock = ref.watch(useMockProvider);
    final google = !mock;
    final phone = mock || AppConstants.enablePhoneLogin;
    final showPhoneForm = phone && (!google || _phoneOpen);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 48),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: 134, child: BrandMark()),
                      ),
                      const SizedBox(height: 28),
                      const _HeroPhotos(),
                      const SizedBox(height: 30),
                      const Text(
                        '讓失物，回到日常。',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '登入後就能瀏覽附近的失物、刊登遺失或拾獲的物品，並直接聯絡對方。',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Highlights(),
                      const SizedBox(height: 30),
                      if (google)
                        GoogleAccountButton(
                          onToken: _google,
                          onError: (message) =>
                              setState(() => _error = message),
                        ),
                      if (google && phone && !_phoneOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            onPressed: () => setState(() => _phoneOpen = true),
                            child: const Text('改用手機號碼登入'),
                          ),
                        ),
                      if (google)
                        TextButton(
                          onPressed: _busy ? null : _invited,
                          child: const Text('受邀帳號登入'),
                        ),
                      if (showPhoneForm) ...[
                        if (google) const SizedBox(height: 18),
                        _phoneForm(mock),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.error600,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        google
                            ? '使用 Google 安全登入，不需另設密碼。'
                            : '體驗模式不會發送簡訊，也不會建立真實帳號。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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

  Widget _phoneForm(bool mock) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          onFieldSubmitted: (_) => _sendOtp(),
          validator: (_) => RegExp(r'^09\d{8}$').hasMatch(_normalizedPhone)
              ? null
              : '請輸入 09 開頭的 10 位手機號碼',
          decoration: InputDecoration(
            labelText: '台灣手機號碼',
            hintText: '0912 345 678',
            errorMaxLines: 3,
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: const Icon(
              Icons.phone_iphone_rounded,
              color: AppColors.primary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (mock)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : () => _phone.text = '0912345678',
              child: const Text(
                '帶入示範手機 0912345678',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Text(mock ? '體驗手機驗證' : '取得驗證碼'),
        ),
      ],
    ),
  );
}

/// 三張物品照片疊放，讓第一眼就知道這是「失物」App。
class _HeroPhotos extends StatelessWidget {
  const _HeroPhotos();

  @override
  Widget build(BuildContext context) {
    Widget photo(String asset, String label, double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 108,
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F282B30),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 2),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 190,
              child: Center(
                child: photo('assets/images/wallet.jpg', '錢包', -.09),
              ),
            ),
            Positioned(
              left: 190,
              right: 0,
              child: Center(
                child: photo('assets/images/earbuds.jpg', '耳機', .08),
              ),
            ),
            photo('assets/images/backpack.jpg', '背包', 0),
          ],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        row(Icons.map_outlined, '在地圖上看附近有人撿到什麼'),
        row(Icons.chat_bubble_outline_rounded, '直接和拾獲者或失主對話'),
        row(Icons.qr_code_2_rounded, '幫重要物品貼上 QR 防丟貼'),
      ],
    );
  }
}
