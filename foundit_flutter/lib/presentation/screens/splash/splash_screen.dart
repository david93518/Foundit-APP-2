import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scale = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    _logoCtrl.forward();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final done = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
    final loggedIn = prefs.getBool(AppConstants.prefIsLoggedIn) ?? false;
    if (!done) {
      context.go('/onboarding');
    } else if (loggedIn) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            // 裝飾性模糊圓斑（glow）
            Positioned(
              top: -80,
              left: -40,
              child: _Glow(color: Colors.white.withValues(alpha: 0.15), size: 260),
            ),
            Positioned(
              bottom: -120,
              right: -60,
              child: _Glow(color: AppColors.primary200.withValues(alpha: 0.35), size: 320),
            ),
            Positioned(
              top: 180,
              right: 40,
              child: _Glow(color: AppColors.found400.withValues(alpha: 0.3), size: 160),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1).animate(_scale),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseLogo(pulseCtrl: _pulseCtrl),
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppConstants.appSlogan,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: _LoadingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseLogo extends StatelessWidget {
  const _PulseLogo({required this.pulseCtrl});
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _Ring(progress: pulseCtrl.value),
              _Ring(progress: (pulseCtrl.value + 0.33) % 1),
              _Ring(progress: (pulseCtrl.value + 0.66) % 1),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (rect) => AppColors.heroGradient.createShader(rect),
                  child: const Icon(
                    Icons.search_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(progress);
    return Container(
      width: 100 + 60 * t,
      height: 100 + 60 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: (1 - t) * 0.45),
          width: 2,
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 20)],
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_c.value * 2 * math.pi) + i * 0.6;
            final v = (math.sin(phase) + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4 + 0.6 * v),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
