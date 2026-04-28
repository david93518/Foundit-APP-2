import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../providers/core_providers.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/item_card.dart';

/// AI 智慧配對頁 — 上傳照片，後端依關鍵字 + 規則做配對
class AiMatchScreen extends ConsumerStatefulWidget {
  const AiMatchScreen({super.key});

  @override
  ConsumerState<AiMatchScreen> createState() => _AiMatchScreenState();
}

class _AiMatchScreenState extends ConsumerState<AiMatchScreen>
    with SingleTickerProviderStateMixin {
  String? _photoUrl;
  File? _localFile;
  bool _analyzing = false;
  String? _errorMessage;
  List<AiMatchResult> _results = const [];
  late final AnimationController _scanCtrl;
  final TextEditingController _keywordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      _localFile = File(picked.path);
      _photoUrl = picked.path;
      _analyzing = true;
      _errorMessage = null;
      _results = const [];
    });
    await _runMatch();
  }

  Future<void> _searchByKeyword() async {
    final kw = _keywordCtrl.text.trim();
    if (kw.isEmpty) {
      AppSnackbar.warning(context, '請輸入關鍵字');
      return;
    }
    setState(() {
      _localFile = null;
      _photoUrl = null;
      _analyzing = true;
      _errorMessage = null;
      _results = const [];
    });
    await _runMatch();
  }

  Future<void> _runMatch() async {
    try {
      String? remoteImageUrl;
      if (_localFile != null) {
        remoteImageUrl =
            await ref.read(uploadRepositoryProvider).uploadImage(_localFile!);
      }
      final keyword = _keywordCtrl.text.trim();
      final results = await ref.read(aiRepositoryProvider).match(
            keyword: keyword.isEmpty ? null : keyword,
            imageUrl: remoteImageUrl,
          );
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _results = results;
        if (remoteImageUrl != null) {
          _photoUrl = remoteImageUrl;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = '配對失敗：$e';
      });
    }
  }

  void _reset() {
    setState(() {
      _localFile = null;
      _photoUrl = null;
      _analyzing = false;
      _errorMessage = null;
      _results = const [];
      _keywordCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: _photoUrl == null && _results.isEmpty && !_analyzing
                  ? _PickPhoto(
                      onPickPhoto: _pickPhoto,
                      keywordCtrl: _keywordCtrl,
                      onSearch: _searchByKeyword,
                    )
                  : _analyzing
                      ? _Analyzing(url: _photoUrl, ctrl: _scanCtrl)
                      : _Results(
                          url: _photoUrl,
                          results: _results,
                          errorMessage: _errorMessage,
                        ),
            ),
            if (_photoUrl != null || _results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GradientButton(
                  label: '重新搜尋',
                  icon: Icons.refresh_rounded,
                  onPressed: _reset,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.allSm,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text('AI 智慧配對',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickPhoto extends StatelessWidget {
  const _PickPhoto({
    required this.onPickPhoto,
    required this.keywordCtrl,
    required this.onSearch,
  });
  final VoidCallback onPickPhoto;
  final TextEditingController keywordCtrl;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '上傳照片或輸入關鍵字',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          const Text(
            '我們會比對全站物品，找出最相似的候選清單。',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onPickPhoto,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary50,
                    AppColors.primary100.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: AppRadius.allLg,
                border: Border.all(
                  color: AppColors.primary300,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.primary,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '點擊上傳照片',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _OrDivider(),
          const SizedBox(height: 20),
          TextField(
            controller: keywordCtrl,
            decoration: const InputDecoration(
              labelText: '關鍵字搜尋',
              hintText: '例：黑色錢包、iPhone 15、悠遊卡…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: '開始配對',
            icon: Icons.auto_awesome_rounded,
            onPressed: onSearch,
          ),
          const SizedBox(height: 22),
          const Text(
            '智慧分析流程',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            step: '01',
            icon: Icons.visibility_rounded,
            gradient: AppColors.primaryGradient,
            title: '關鍵字比對',
            desc: '從標題、描述、類別中找出相符',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            step: '02',
            icon: Icons.swap_horiz_rounded,
            gradient: AppColors.mintGradient,
            title: '對立媒合',
            desc: '遺失物自動配對拾獲物，反之亦然',
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            step: '03',
            icon: Icons.schedule_rounded,
            gradient: AppColors.sunsetGradient,
            title: '時間相近加權',
            desc: '優先呈現時間範圍接近的物品',
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('或',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.step,
    required this.icon,
    required this.gradient,
    required this.title,
    required this.desc,
  });
  final String step;
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allMd,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppRadius.allSm,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            step,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing({required this.url, required this.ctrl});
  final String? url;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (url != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.allLg,
                boxShadow: AppShadows.lg,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.allLg,
                child: Stack(
                  children: [
                    _PreviewImage(url: url!, height: 320),
                    AnimatedBuilder(
                      animation: ctrl,
                      builder: (_, __) => Positioned(
                        left: 0,
                        right: 0,
                        top: 320 * ctrl.value - 6,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF6366F1),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.7),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: AppRadius.allLg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            '分析中…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'AI 正在比對全站物品特徵與關鍵字',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.url,
    required this.results,
    this.errorMessage,
  });
  final String? url;
  final List<AiMatchResult> results;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('找不到相符結果',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.found50,
                  AppColors.primary50,
                ],
              ),
              borderRadius: AppRadius.allLg,
            ),
            child: Row(
              children: [
                if (url != null)
                  ClipRRect(
                    borderRadius: AppRadius.allSm,
                    child: _PreviewImage(url: url!, width: 60, height: 60),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: AppRadius.allSm,
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 28),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.found, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '分析完成',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '找到 ${results.length} 件相似物品',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '目前沒有找到相符的物品',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Text('配對結果',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.allRound,
                  ),
                  child: Text(
                    '${results.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultRow(result: r),
                )),
          ],
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url, this.width, this.height});
  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isFile = !url.startsWith('http');
    if (isFile) {
      return Image.file(
        File(url),
        width: width ?? double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(color: AppColors.primary100),
      );
    }
    return Image.network(
      url,
      width: width ?? double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: AppColors.primary100),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});
  final AiMatchResult result;

  @override
  Widget build(BuildContext context) {
    final score = result.similarityPercent;
    final color = score > 80
        ? AppColors.found
        : score > 60
            ? AppColors.reward
            : AppColors.textTertiary;

    return Stack(
      children: [
        ListItemCard(
          item: result.item,
          onTap: () =>
              context.push('/item/${result.item.id}', extra: result.item),
        ),
        Positioned(
          right: 18,
          top: 22,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color,
                color.withValues(alpha: 0.8),
              ]),
              borderRadius: AppRadius.allRound,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.percent_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
