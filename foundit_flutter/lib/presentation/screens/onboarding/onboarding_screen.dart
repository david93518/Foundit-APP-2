import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptics.dart';

/// 首次啟動導覽 — 三頁 PageView + 漸層背景 + 動畫插圖
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _index = 0;

  final _pages = const [
    _OnboardPage(
      emoji: '🔍',
      iconBg: Icons.travel_explore_rounded,
      title: '找得到，讓失去\n有機會找回',
      desc: '社群共享的遺失物平台，每個人都可以當好心人。',
      gradient: AppColors.heroGradient,
      decorColor: Color(0xFFA5B4FC),
    ),
    _OnboardPage(
      emoji: '✨',
      iconBg: Icons.auto_awesome_rounded,
      title: 'AI 幫你配對\n找回機率更高',
      desc: '上傳一張照片，讓 AI 掃描全站相似物，節省你翻找時間。',
      gradient: AppColors.mintGradient,
      decorColor: Color(0xFF6EE7B7),
    ),
    _OnboardPage(
      emoji: '💚',
      iconBg: Icons.volunteer_activism_rounded,
      title: '加入溫暖社群\n成為那道光',
      desc: '完成歸還還能累積積分與徽章，讓善意被看見。',
      gradient: AppColors.sunsetGradient,
      decorColor: Color(0xFFFBBF24),
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    Haptics.medium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
    if (!mounted) return;
    context.go('/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      Haptics.light();
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(gradient: page.gradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      '跳過',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    Haptics.select();
                    setState(() => _index = i);
                  },
                  itemBuilder: (_, i) => _OnboardPageView(page: _pages[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _ctrl,
                      count: _pages.length,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 4,
                        spacing: 6,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.white,
                        borderRadius: AppRadius.allMd,
                        child: InkWell(
                          borderRadius: AppRadius.allMd,
                          onTap: _next,
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.allMd,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  transitionBuilder: (c, a) =>
                                      FadeTransition(opacity: a, child: c),
                                  child: Text(
                                    _isLast ? '開始使用' : '下一頁',
                                    key: ValueKey(_isLast),
                                    style: const TextStyle(
                                      color: AppColors.primary700,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  child: Icon(
                                    _isLast
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    key: ValueKey(_isLast),
                                    color: AppColors.primary700,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPageView extends StatefulWidget {
  const _OnboardPageView({required this.page});
  final _OnboardPage page;

  @override
  State<_OnboardPageView> createState() => _OnboardPageViewState();
}

class _OnboardPageViewState extends State<_OnboardPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 240 + _pulse.value * 30,
                      height: 240 + _pulse.value * 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: 0.12 - _pulse.value * 0.08),
                      ),
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.page.emoji,
                        style: const TextStyle(fontSize: 76)),
                  ),
                  Positioned(
                    top: 40,
                    right: 10,
                    child: _FloatingBadge(
                      icon: widget.page.iconBg,
                      color: widget.page.decorColor,
                      pulse: _pulse,
                      delay: 0,
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 20,
                    child: _FloatingBadge(
                      icon: Icons.favorite_rounded,
                      color: widget.page.decorColor,
                      pulse: _pulse,
                      delay: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            widget.page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.page.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.color,
    required this.pulse,
    required this.delay,
  });
  final IconData icon;
  final Color color;
  final AnimationController pulse;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final v = ((pulse.value + delay) % 1.0);
        final offset = -8 * (1 - (v - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        );
      },
    );
  }
}

class _OnboardPage {
  final String emoji;
  final IconData iconBg;
  final String title;
  final String desc;
  final Gradient gradient;
  final Color decorColor;
  const _OnboardPage({
    required this.emoji,
    required this.iconBg,
    required this.title,
    required this.desc,
    required this.gradient,
    required this.decorColor,
  });
}
