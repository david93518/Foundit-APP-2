import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/foundit_ui.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.now});
  final String phone;

  /// Clock injection keeps the resend deadline testable, including app resumes.
  final DateTime Function()? now;
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _seconds = 60;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _notice;
  bool get _validPhone => RegExp(r'^09\d{8}$').hasMatch(widget.phone);

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _seconds = 60;
    final clock = widget.now ?? DateTime.now;
    final deadline = clock().add(const Duration(seconds: 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = (deadline.difference(clock()).inMilliseconds / 1000)
          .ceil();
      setState(() => _seconds = remaining > 0 ? remaining : 0);
      if (_seconds == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _verify() async {
    if (_busy || _resending || !_validPhone || _code.text.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final ok = await ref
          .read(authProvider.notifier)
          .verifyOtp(widget.phone, _code.text);
      if (!mounted) return;
      if (ok) {
        TextInput.finishAutofillContext();
        context.pop(true);
      } else {
        final detail = (ref.read(authProvider).error ?? '').toLowerCase();
        final connectionError = RegExp(
          r'connection|timeout|socket|network|500|503',
        ).hasMatch(detail);
        setState(
          () => _error = connectionError
              ? '目前無法連線驗證，請稍後重試。'
              : '驗證碼不正確或已過期，請確認後再試一次。',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '目前無法驗證，請確認網路連線後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _busy || _resending || !_validPhone) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      final ok = await ref.read(authProvider.notifier).sendOtp(widget.phone);
      if (!mounted) return;
      if (ok) {
        _code.clear();
        _startCountdown();
        setState(
          () => _notice = ref.read(useMockProvider)
              ? '體驗驗證已準備好，輸入 123456 即可。'
              : '已重新取得驗證碼，請查看手機簡訊。',
        );
      } else {
        setState(() => _error = '暫時無法重新取得驗證碼，請稍後再試。');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '目前無法連線，請稍後重試。');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mock = ref.watch(useMockProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _back,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('更換手機號碼'),
                      ),
                    ),
                    const SizedBox(height: 38),
                    const BrandMark(),
                    const SizedBox(height: 38),
                    const Text(
                      '再一步，讓線索連起來。',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _validPhone
                          ? '手機號碼 ${widget.phone}\n請輸入 6 位數驗證碼，繼續剛才的操作。'
                          : '請先返回上一頁，輸入有效的手機號碼。',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (mock) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '體驗驗證 · 不會發送簡訊\n輸入 123456 即可繼續。',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            height: 1.8,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    TextField(
                      controller: _code,
                      enabled: _validPhone && !_busy && !_resending,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _verify(),
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        labelText: '6 位數驗證碼',
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          letterSpacing: 0,
                        ),
                        hintText: '000000',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
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
                    if (_error != null || _notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error ?? _notice!,
                            style: TextStyle(
                              color: _error != null
                                  ? AppColors.error600
                                  : AppColors.primary,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          _validPhone &&
                              _code.text.length == 6 &&
                              !_busy &&
                              !_resending
                          ? _verify
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
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
                          : Text(mock ? '完成體驗登入' : '確認並繼續'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          _seconds == 0 && !_busy && !_resending && _validPhone
                          ? _resend
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        _resending
                            ? '正在重新取得…'
                            : _seconds > 0
                            ? '$_seconds 秒後可重新取得驗證碼'
                            : '重新取得驗證碼',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
