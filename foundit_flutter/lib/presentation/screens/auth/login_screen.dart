import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/haptics.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';

/// 登入頁 — 上方漸層插畫、下方圓角白卡片浮出
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _googleSigningIn = false;
  bool get _canSend =>
      _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneCtrl.text.trim();
    final ok = await ref.read(authProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    if (ok) {
      context.push('/otp', extra: phone);
    } else {
      final err = ref.read(authProvider).error ?? '送出驗證碼失敗';
      AppSnackbar.error(context, err);
    }
  }

  Future<void> _signInWithGoogle() async {
    Haptics.light();
    setState(() => _googleSigningIn = true);
    try {
      // Mock 模式直接走假流程，方便不接後端時測試
      if (AppConstants.useMock) {
        final ok = await ref.read(authProvider.notifier).oauthLogin(
              provider: 'google',
              token: 'mock_google_id_token',
              name: 'Google 使用者',
              avatarUrl: 'https://i.pravatar.cc/150?img=12',
            );
        if (!mounted) return;
        if (ok) {
          context.go('/home');
        } else {
          AppSnackbar.error(context, ref.read(authProvider).error ?? 'Google 登入失敗');
        }
        return;
      }

      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConstants.googleWebClientId,
      );
      // 強制重新選帳號，避免快取舊登入
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        // 使用者取消
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (!mounted) return;
        AppSnackbar.error(context,
            '未取得 Google idToken：請確認 Google Cloud Console 已建立「網頁應用程式」OAuth 用戶端');
        return;
      }
      final ok = await ref.read(authProvider.notifier).oauthLogin(
            provider: 'google',
            token: idToken,
            name: account.displayName,
            avatarUrl: account.photoUrl,
          );
      if (!mounted) return;
      if (ok) {
        context.go('/home');
      } else {
        AppSnackbar.error(
            context, ref.read(authProvider).error ?? 'Google 登入失敗');
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Google 登入失敗：$e');
    } finally {
      if (mounted) setState(() => _googleSigningIn = false);
    }
  }

  void _signInWithLine() {
    AppSnackbar.info(context, 'LINE 登入即將推出，請先使用手機 OTP 或 Google 登入');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final authState = ref.watch(authProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _HeroTop(height: height * 0.42),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height * 0.62),
                child: Container(
                  margin: EdgeInsets.only(top: height * 0.38),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.topXl,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '歡迎回來',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '輸入手機號碼，我們會寄送驗證碼給您',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      _PhoneField(controller: _phoneCtrl),
                      const SizedBox(height: AppSpacing.xxl),
                      GradientButton(
                        label: authState.otpSending ? '傳送中…' : '取得驗證碼',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: (_canSend && !authState.otpSending)
                            ? _sendOtp
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _Divider(),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              label: 'Google',
                              leading: const _GoogleLogo(size: 22),
                              onTap: _googleSigningIn ? null : _signInWithGoogle,
                              busy: _googleSigningIn,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _SocialButton(
                              label: 'LINE',
                              leading: const Icon(Icons.chat_bubble_rounded,
                                  color: Color(0xFF06C755), size: 22),
                              onTap: _signInWithLine,
                              comingSoon: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/home'),
                          child: Text(
                            '先逛逛，稍後再登入',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTop extends StatelessWidget {
  const _HeroTop({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: _Bubble(size: 180, color: Colors.white.withValues(alpha: 0.15)),
          ),
          Positioned(
            top: 100,
            left: -40,
            child: _Bubble(size: 140, color: AppColors.found400.withValues(alpha: 0.2)),
          ),
          Positioned(
            bottom: 80,
            right: 80,
            child: _Bubble(size: 60, color: AppColors.reward400.withValues(alpha: 0.3)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.allMd,
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '把遺失找回來，\n把拾獲送回家。',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 10)],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\s+\-]')),
      ],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixIcon: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary100,
            borderRadius: AppRadius.allSm,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇹🇼 +886',
                  style: TextStyle(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        hintText: '9 12 345 678',
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '或',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onTap,
    this.busy = false,
    this.comingSoon = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onTap;
  final bool busy;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final dim = disabled || comingSoon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: dim ? 0.55 : 1,
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.allMd,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.allMd,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.allMd,
                  border: Border.all(color: AppColors.divider, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      leading,
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (comingSoon)
          Positioned(
            top: -8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '即將推出',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 簡化版 Google G 標誌（多色）
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;
    final stroke = w * 0.18;

    // 四段彩色圓弧（仿 Google G 顏色）
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // 紅 / 黃 / 綠 / 藍
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _deg(-30), _deg(80), false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _deg(50), _deg(80), false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _deg(130), _deg(80), false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _deg(210), _deg(120), false, paint);

    // 中央橫線（藍）
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - stroke / 2.2, r - stroke / 2, stroke / 1.1),
      barPaint,
    );
  }

  double _deg(double d) => d * 3.1415926535 / 180.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
