import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _seconds = 59;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(() {
      if (!mounted) return;
      if (_seconds > 0) {
        setState(() => _seconds--);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();
  bool get _canSubmit => _code.length == 6;

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .verifyOtp(widget.phone, _code);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      final err = ref.read(authProvider).error ?? '驗證失敗';
      AppSnackbar.error(context, err);
    }
  }

  Future<void> _resend() async {
    setState(() => _seconds = 59);
    final ok = await ref.read(authProvider.notifier).sendOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, '已重新傳送驗證碼');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppRadius.allMd,
                  boxShadow: AppShadows.primary,
                ),
                child: const Icon(Icons.sms_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '輸入驗證碼',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  text: '6 位數驗證碼已寄至 ',
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: widget.phone.isEmpty ? '您的手機' : widget.phone,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: _seconds > 0
                    ? Text(
                        '$_seconds 秒後可重新取得',
                        style: Theme.of(context).textTheme.labelMedium,
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('重新取得驗證碼'),
                      ),
              ),
              const SizedBox(height: AppSpacing.huge),
              GradientButton(
                label: authState.loading ? '驗證中…' : '登入',
                onPressed: (_canSubmit && !authState.loading) ? _verify : null,
                icon: Icons.login_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 48,
      height: 60,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: _ctrls[i].text.isEmpty
              ? AppColors.surfaceSoft
              : AppColors.primary50,
          border: OutlineInputBorder(
            borderRadius: AppRadius.allMd,
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadius.allMd,
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (v) {
          setState(() {});
          if (v.isNotEmpty && i < 5) {
            _nodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _nodes[i - 1].requestFocus();
          }
        },
      ),
    );
  }
}

/// Simple ticker for countdown without importing flutter/scheduler heavy deps
class Ticker {
  Ticker(this.onTick);
  final VoidCallback onTick;
  bool _running = false;

  void start() {
    _running = true;
    _loop();
  }

  Future<void> _loop() async {
    while (_running) {
      await Future.delayed(const Duration(seconds: 1));
      if (_running) onTick();
    }
  }

  void dispose() {
    _running = false;
  }
}
