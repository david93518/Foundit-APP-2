import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/item.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/share_sheet.dart';
import '../../widgets/type_badge.dart';

/// 收藏 prefs key 前綴 — 讓 ProfileScreen 等其他頁能 reuse
String bookmarkPrefKey(String itemId) => 'bookmark:$itemId';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.item});
  final Item item;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen>
    with TickerProviderStateMixin {
  bool _bookmarked = false;
  late final AnimationController _bookmarkCtrl;
  final PageController _imgCtrl = PageController();
  int _imgIndex = 0;

  @override
  void initState() {
    super.initState();
    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = ref.read(sharedPreferencesProvider);
      final saved = prefs.getBool(bookmarkPrefKey(widget.item.id)) ?? false;
      if (mounted) setState(() => _bookmarked = saved);
    });
  }

  @override
  void dispose() {
    _bookmarkCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    Haptics.medium();
    final next = !_bookmarked;
    setState(() => _bookmarked = next);
    final prefs = ref.read(sharedPreferencesProvider);
    if (next) {
      await prefs.setBool(bookmarkPrefKey(widget.item.id), true);
      _bookmarkCtrl.forward(from: 0);
      if (mounted) AppSnackbar.success(context, '已加入我的關注');
    } else {
      await prefs.remove(bookmarkPrefKey(widget.item.id));
      if (mounted) AppSnackbar.info(context, '已取消關注');
    }
  }

  void _share() {
    Haptics.light();
    showShareSheet(
      context,
      title: widget.item.title,
      link: 'https://foundit.com.tw/i/${widget.item.id}',
    );
  }

  void _openGallery(int index) {
    Haptics.light();
    if (widget.item.images.isEmpty) return;
    context.push(
      '/photo-viewer',
      extra: {
        'images': widget.item.images,
        'initialIndex': index,
        'heroTag': 'item_image_${widget.item.id}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = media.size.height * 0.55;
    final item = widget.item;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _HeroCarousel(
            item: item,
            height: heroHeight,
            controller: _imgCtrl,
            index: _imgIndex,
            onPageChanged: (i) => setState(() => _imgIndex = i),
            onTap: _openGallery,
          ),
          _Sheet(item: item, heroHeight: heroHeight),
          _TopBar(
            onBack: () => context.pop(),
            bookmarked: _bookmarked,
            onBookmark: _toggleBookmark,
            bookmarkCtrl: _bookmarkCtrl,
            onShare: _share,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomCTA(item: item),
          ),
        ],
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.item,
    required this.height,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    required this.onTap,
  });

  final Item item;
  final double height;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (item.images.isEmpty) {
      return SizedBox(
        height: height,
        child: Hero(
          tag: 'item_image_${item.id}',
          child: Container(
            color: AppColors.neutral100,
            alignment: Alignment.center,
            child: const Text('📦', style: TextStyle(fontSize: 96)),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: item.images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onTap(i),
              child: Hero(
                tag: i == 0
                    ? 'item_image_${item.id}'
                    : 'item_image_${item.id}_$i',
                child: CachedNetworkImage(
                  imageUrl: item.images[i],
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.neutral100),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.neutral100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded, size: 48),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  stops: const [0, 0.18, 0.6, 1],
                ),
              ),
            ),
          ),
          if (item.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: height * 0.08 + 10,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: AppRadius.allRound,
                  ),
                  child: SmoothPageIndicator(
                    controller: controller,
                    count: item.images.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 6,
                      dotWidth: 6,
                      expansionFactor: 3,
                      spacing: 4,
                      activeDotColor: Colors.white,
                      dotColor: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 56,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: AppRadius.allRound,
              ),
              child: Text(
                '${index + 1} / ${item.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.item, required this.heroHeight});
  final Item item;
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.only(top: heroHeight - 32),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - heroHeight + 32,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.topXl,
          boxShadow: AppShadows.lg,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: AppRadius.allRound,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  TypeBadge(type: item.type),
                  const SizedBox(width: 8),
                  _CategoryChip(category: item.category),
                  const Spacer(),
                  if (item.hasReward && item.reward > 0)
                    RewardBadge(amount: item.reward),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                item.title,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoPoster(item: item),
              const SizedBox(height: AppSpacing.xxl),
              _infoRow(
                context,
                Icons.place_rounded,
                '地點',
                item.locationName.isEmpty ? '未知地點' : item.locationName,
              ),
              const SizedBox(height: AppSpacing.lg),
              _infoRow(
                context,
                Icons.access_time_rounded,
                item.type == ItemType.lost ? '遺失時間' : '拾獲時間',
                DateFormatter.full(item.lostAt),
              ),
              if (item.color.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _infoRow(context, Icons.palette_rounded, '顏色', item.color),
              ],
              if (item.storageLocation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _infoRow(context, Icons.warehouse_rounded, '保管處',
                    item.storageLocation),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '物品描述',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.description.isEmpty ? '（無描述）' : item.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _MapPreview(lat: item.latitude, lng: item.longitude),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPoster extends StatelessWidget {
  const _InfoPoster({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.allMd,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: item.userAvatar.isEmpty
                ? null
                : NetworkImage(item.userAvatar),
            backgroundColor: AppColors.primary200,
            child: item.userAvatar.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.userName.isEmpty ? '匿名用戶' : item.userName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.relative(item.createdAt)} · 發佈',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (item.userVerified)
            Row(
              children: const [
                Icon(Icons.verified_rounded,
                    color: AppColors.found, size: 16),
                SizedBox(width: 4),
                Text('已驗證',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.found,
                        fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.allRound,
      ),
      child: Text(
        category.isEmpty ? '未分類' : category,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.lat, required this.lng});
  final double lat;
  final double lng;

  Future<void> _openExternalMap(BuildContext context) async {
    if (lat == 0 && lng == 0) {
      AppSnackbar.info(context, '此物品沒有位置資訊');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppSnackbar.error(context, '無法開啟地圖');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = lat != 0 || lng != 0;
    return GestureDetector(
      onTap: hasLocation ? () => _openExternalMap(context) : null,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary100.withValues(alpha: 0.6),
              AppColors.found100.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: AppRadius.allMd,
        ),
        child: Stack(
          children: [
            CustomPaint(size: Size.infinite, painter: _GridPainter()),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.primary,
                    ),
                    child: const Icon(Icons.place_rounded,
                        color: Colors.white, size: 28),
                  ),
                  if (!hasLocation) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '無位置資訊',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasLocation)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: AppRadius.allSm,
                  child: InkWell(
                    borderRadius: AppRadius.allSm,
                    onTap: () => _openExternalMap(context),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Google 地圖',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.bookmarked,
    required this.onBookmark,
    required this.bookmarkCtrl,
    required this.onShare,
  });

  final VoidCallback onBack;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final AnimationController bookmarkCtrl;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _GlassButton(
                  icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const Spacer(),
              _BookmarkButton(
                active: bookmarked,
                onTap: onBookmark,
                ctrl: bookmarkCtrl,
              ),
              const SizedBox(width: 8),
              _GlassButton(icon: Icons.ios_share_rounded, onTap: onShare),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}

/// 含「愛心彈跳 + 閃光」動畫的收藏按鈕
class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({
    required this.active,
    required this.onTap,
    required this.ctrl,
  });

  final bool active;
  final VoidCallback onTap;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) {
            final v = ctrl.value;
            return IgnorePointer(
              child: Opacity(
                opacity: v < 0.6 ? (v / 0.6) : (1 - (v - 0.6) / 0.4),
                child: Transform.scale(
                  scale: 1 + v * 0.8,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lost,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Material(
          color: Colors.white.withValues(alpha: 0.85),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  active
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(active),
                  color: active ? AppColors.lost : AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomCTA extends ConsumerStatefulWidget {
  const _BottomCTA({required this.item});
  final Item item;

  @override
  ConsumerState<_BottomCTA> createState() => _BottomCTAState();
}

class _BottomCTAState extends ConsumerState<_BottomCTA> {
  bool _busy = false;

  Future<void> _onContact() async {
    if (_busy) return;
    Haptics.light();

    final prefs = ref.read(sharedPreferencesProvider);
    final myId = prefs.getString(AppConstants.prefUserId) ?? '';
    if (myId.isEmpty) {
      AppSnackbar.warning(context, '請先登入才能聯絡對方');
      return;
    }
    if (myId == widget.item.userId) {
      AppSnackbar.info(context, '這是你自己貼的物品');
      return;
    }

    setState(() => _busy = true);
    try {
      final chat = await ref
          .read(chatRepositoryProvider)
          .createChat(itemId: widget.item.id);
      if (!mounted) return;
      if (chat == null) {
        AppSnackbar.error(context, '無法建立聊天室，請稍後再試');
        return;
      }
      ref.invalidate(chatsProvider);
      context.push('/chat/${chat.id}', extra: {
        'name': chat.otherUserName.isEmpty
            ? widget.item.userName
            : chat.otherUserName,
        'avatar': chat.otherUserAvatar.isEmpty
            ? widget.item.userAvatar
            : chat.otherUserAvatar,
        'itemTitle': chat.itemTitle.isEmpty
            ? widget.item.title
            : chat.itemTitle,
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      AppSnackbar.error(
        context,
        msg.contains('400')
            ? '不能和自己的物品開啟聊天'
            : '無法建立聊天室：$msg',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLost = widget.item.type == ItemType.lost;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.lg,
      ),
      child: Row(
        children: [
          _OutlineAction(
            icon: Icons.auto_awesome_rounded,
            onTap: () => context.push('/ai-match'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GradientButton(
              label: _busy
                  ? '建立中…'
                  : (isLost ? '我看到了，聯絡失主' : '這是我的，聯絡撿到者'),
              icon: Icons.chat_bubble_rounded,
              gradient: isLost
                  ? AppColors.sunsetGradient
                  : AppColors.mintGradient,
              onPressed: _busy ? null : _onContact,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            border: Border.all(color: AppColors.divider, width: 1.2),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
