import 'dart:convert';
import 'dart:math' as math;

export 'brand_mark.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';

// Compatibility aliases for existing screens; primary actions share brand tokens.
const forest = AppColors.primary;
const coral = AppColors.primary;

/// 動效節奏。整個 App 共用同一組時間與曲線，動作才會有一致的「手感」。
class AppMotion {
  AppMotion._();
  static const quick = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;

  /// 尊重系統「減少動態效果」設定。
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, Set<String>>((ref) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return SavedItemsNotifier(ref);
    });

String savedNamespace(SharedPreferences prefs) {
  final id = prefs.getString(AppConstants.prefUserId);
  return (id == null || id.isEmpty) ? 'guest' : id;
}

String savedItemKey(SharedPreferences prefs, String itemId) =>
    'bookmark:${savedNamespace(prefs)}:$itemId';

class SavedItemsNotifier extends StateNotifier<Set<String>> {
  SavedItemsNotifier(this.ref) : super(_read(ref));
  final Ref ref;

  static Set<String> _read(Ref ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final prefix = 'bookmark:${savedNamespace(prefs)}:';
    return prefs
        .getKeys()
        .where((key) => key.startsWith(prefix) && prefs.getBool(key) == true)
        .map((key) => key.substring(prefix.length))
        .toSet();
  }

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(savedItemKey(prefs, id), next.contains(id));
  }
}

/// 物品照片：資產、data URI 或網路圖片都走這裡，載入失敗時顯示品牌占位。
class ItemPhoto extends StatelessWidget {
  const ItemPhoto(this.source, {super.key, this.fit = BoxFit.cover});
  final String? source;
  final BoxFit fit;

  Widget fallback() => const ColoredBox(
    color: AppColors.primary50,
    child: Center(
      child: BracketMark(
        size: 44,
        color: AppColors.primary200,
        strokeWidth: 2.4,
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppColors.primary300,
          size: 20,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = source ?? '';
    if (s.isEmpty) return fallback();
    if (s.startsWith('assets/')) {
      return Image.asset(s, fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    if (s.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(s.split(',').last),
          fit: fit,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    }
    return ColoredBox(
      color: AppColors.neutral100,
      child: Image.network(
        s,
        fit: fit,
        frameBuilder: (context, child, frame, loadedSync) => loadedSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AppMotion.of(context, AppMotion.slow),
                curve: Curves.easeOut,
                child: child,
              ),
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

String itemStatusLabel(Item item) => item.status == ItemStatus.resolved
    ? (item.type == ItemType.found ? '已交還' : '已找回')
    : item.type == ItemType.found
    ? '待認領'
    : '協尋中';

/// 狀態標籤：陶土＝撿到、炭墨＝遺失，前面的小圓點讓色弱使用者也能分辨。
class StatusTag extends StatelessWidget {
  const StatusTag(this.item, {super.key, this.onPhoto = false});
  final Item item;

  /// 疊在照片上時使用白底，確保任何照片上都讀得到。
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final resolved = item.status == ItemStatus.resolved;
    final found = item.type == ItemType.found;
    final base = resolved
        ? AppColors.textSecondary
        : found
        ? AppColors.primary700
        : AppColors.ink;
    // 疊在照片上時永遠用亮色模式的值：照片不會跟著變暗。
    final fg = onPhoto ? base.light : base;
    final bg = onPhoto
        ? Colors.white.withValues(alpha: .94)
        : resolved
        ? AppColors.surfaceSoft
        : found
        ? AppColors.primary50
        : AppColors.ink50;
    final label = Text(
      itemStatusLabel(item),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          // 照片上的寬度由 [_PhotoBadges] 決定，極窄時以省略號收尾而不是溢出；
          // 其他地方（詳情、地圖）可能放在不限寬的 Row 裡，不能用 Flexible。
          onPhoto ? Flexible(child: label) : label,
        ],
      ),
    );
  }
}

/// 按下時微縮的觸控回饋（取代 Material 水波），搭配 Semantics 供輔助工具使用。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .97,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    label: widget.semanticLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.of(context, AppMotion.quick),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

/// 品牌的角括號：把「找到的東西」框起來。用在空狀態、照片占位與上傳區。
class BracketMark extends StatelessWidget {
  const BracketMark({
    super.key,
    this.size = 96,
    this.color = AppColors.textPrimary,
    this.strokeWidth = 3,
    this.child,
  });
  final double size;
  final Color color;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _BracketPainter(color, strokeWidth),
      child: Center(child: child),
    ),
  );
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arm = size.shortestSide * .28;
    final inset = strokeWidth / 2;
    canvas.drawPath(
      Path()
        ..moveTo(inset + arm, inset)
        ..lineTo(inset, inset)
        ..lineTo(inset, inset + arm),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - inset - arm, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// 照片優先的物品卡：狀態疊在照片上，文字只留標題、地點與時間。
///
/// [horizontal] 用在收藏／我的刊登這類單欄清單，照片在左。
class FoundItemCard extends ConsumerStatefulWidget {
  const FoundItemCard({super.key, required this.item, this.horizontal = false});
  final Item item;
  final bool horizontal;
  @override
  ConsumerState<FoundItemCard> createState() => _FoundItemCardState();
}

class _FoundItemCardState extends ConsumerState<FoundItemCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saved = ref.watch(savedItemsProvider).contains(item.id);
    final when =
        '${DateFormatter.relative(item.lostAt)} ${item.type == ItemType.found ? '拾獲' : '遺失'}';
    // 視覺 36px、觸控 48px：小而不難按。
    final bookmark = Tooltip(
      message: saved ? '取消收藏 ${item.title}' : '收藏 ${item.title}',
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(savedItemsProvider.notifier).toggle(item.id),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: _saveRing,
                height: _saveRing,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                  color: saved
                      ? AppColors.primary.light
                      : AppColors.textPrimary.light,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final photo = Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'item-photo-${item.id}',
          child: ItemPhoto(item.images.firstOrNull),
        ),
        Positioned.fill(
          child: _PhotoBadges(
            status: StatusTag(item, onPhoto: true),
            save: bookmark,
            reward: item.hasReward
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      // 疊在照片上：用亮色模式的值，照片不會跟著變暗。
                      color: AppColors.reward100.light,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '酬謝 NT\$${item.reward}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.reward.light,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.place_outlined,
                size: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                item.locationName.isEmpty ? '地點未提供' : item.locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          when,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
    final card = widget.horizontal
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 104, height: 118, child: photo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: text,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(aspectRatio: 4 / 4.6, child: photo),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                child: text,
              ),
            ],
          );
    return Pressable(
      onTap: () => context.push('/item/${item.id}', extra: item),
      semanticLabel: '${itemStatusLabel(item)}，${item.title}',
      child: Container(
        padding: widget.horizontal ? const EdgeInsets.all(10) : EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: card,
      ),
    );
  }
}

/// 收藏鈕看得見的圓；觸控區仍是 48px。
const _saveRing = 36.0;

enum _PhotoSlot { status, reward, save }

/// 酬謝標籤可以放的位置，依偏好排序。
enum _RewardSpot { bottomLeft, belowStatus, besideSave, hidden }

/// 疊在物品照片上的狀態、酬謝與收藏鈕。
///
/// 收藏鈕預設在右上；照片太窄（清單卡只有 104px，或使用者放大字級）
/// 放不下狀態標籤時，改到右下——和角括號同一條對角線——酬謝移到狀態下方
/// 或收藏鈕左側；都放不下就先收起酬謝（物品頁仍看得到）。
/// 連狀態都排不下時，狀態限制在收藏鈕左側、以省略號收尾。
/// 所以不論照片多寬、字多大，收藏鈕的圓都不會蓋住任何標籤上的字。
class _PhotoBadges
    extends SlottedMultiChildRenderObjectWidget<_PhotoSlot, RenderBox> {
  const _PhotoBadges({required this.status, required this.save, this.reward});
  final Widget status;
  final Widget save;
  final Widget? reward;

  @override
  Iterable<_PhotoSlot> get slots => _PhotoSlot.values;

  @override
  Widget? childForSlot(_PhotoSlot slot) => switch (slot) {
    _PhotoSlot.status => status,
    _PhotoSlot.reward => reward,
    _PhotoSlot.save => save,
  };

  @override
  _RenderPhotoBadges createRenderObject(BuildContext context) =>
      _RenderPhotoBadges();
}

class _RenderPhotoBadges extends RenderBox
    with SlottedContainerRenderObjectMixin<_PhotoSlot, RenderBox> {
  /// 標籤距照片邊緣。
  static const _inset = 10.0;

  /// 收藏鈕觸控區距照片邊緣（看得見的圓因此離邊 8px）。
  static const _edge = 2.0;

  /// 標籤與圓、標籤與標籤之間至少留的空隙。
  static const _gap = 4.0;

  /// 依序嘗試的排法：收藏鈕位置 × 酬謝位置。
  static const _plans = [
    (bottom: false, reward: _RewardSpot.bottomLeft), // 原本的樣子
    (bottom: true, reward: _RewardSpot.belowStatus),
    (bottom: true, reward: _RewardSpot.besideSave),
    (bottom: true, reward: _RewardSpot.hidden),
    (bottom: false, reward: _RewardSpot.hidden),
  ];

  /// 最後手段時標籤能畫的範圍；平常是 null，不必裁切。
  Rect? _chipClip;
  bool _rewardHidden = false;
  final _clipLayer = LayerHandle<ClipRectLayer>();

  RenderBox? get _status => childForSlot(_PhotoSlot.status);
  RenderBox? get _reward => childForSlot(_PhotoSlot.reward);
  RenderBox? get _save => childForSlot(_PhotoSlot.save);

  static Offset _offsetOf(RenderBox child) =>
      (child.parentData! as BoxParentData).offset;

  static void _place(RenderBox child, Offset at, BoxConstraints constraints) {
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = at;
  }

  // 只以 Positioned.fill 疊在照片上，大小就是照片的大小。
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final status = _status!;
    final reward = _reward;
    final save = _save!
      ..layout(BoxConstraints.loose(size), parentUsesSize: true);
    // 觸控區比看得見的圓大；只有圓需要避開標籤。
    final ring = math.max(0.0, (save.size.shortestSide - _saveRing) / 2);
    final saveX = size.width - _edge - save.size.width;
    final topRight = Offset(saveX, _edge);
    final bottomRight = Offset(saveX, size.height - _edge - save.size.height);
    // 右側可以貼近到收藏鈕觸控區的邊距，窄照片上的酬謝金額才不會被截掉。
    final full = BoxConstraints(
      maxWidth: math.max(0.0, size.width - _inset - _edge),
    );
    // 圓左側、留了空隙之後還能用的寬度。
    final left = saveX + ring - _gap;
    final beside = BoxConstraints(maxWidth: math.max(0.0, left - _inset));
    final statusRect = const Offset(_inset, _inset) & status.getDryLayout(full);
    bool apart(Rect a, Rect b) =>
        !a.inflate(_gap / 2).overlaps(b.inflate(_gap / 2));
    bool inside(Rect r) => r.top >= 0 && r.bottom <= size.height;

    final wasHidden = _rewardHidden;
    _chipClip = null;
    for (final plan in _plans) {
      final saveAt = plan.bottom ? bottomRight : topRight;
      final ringRect = (saveAt & save.size).deflate(ring);
      final rewardBox = plan.reward == _RewardSpot.besideSave ? beside : full;
      Rect? rewardRect;
      if (reward != null && plan.reward != _RewardSpot.hidden) {
        final r = reward.getDryLayout(rewardBox);
        // 擠在收藏鈕旁只剩「酬…」沒有意義，寧可換下一種排法。
        if (plan.reward == _RewardSpot.besideSave &&
            r.width < reward.getDryLayout(full).width) {
          continue;
        }
        rewardRect = plan.reward == _RewardSpot.belowStatus
            ? Offset(_inset, statusRect.bottom + _gap) & r
            : Offset(_inset, size.height - _inset - r.height) & r;
      }
      final fits =
          [
            statusRect,
            ?rewardRect,
          ].every((chip) => apart(chip, ringRect) && inside(chip)) &&
          (rewardRect == null || apart(statusRect, rewardRect));
      if (!fits) continue;
      _place(status, statusRect.topLeft, full);
      if (reward != null) {
        _place(reward, rewardRect?.topLeft ?? Offset.zero, rewardBox);
      }
      _rewardHidden = reward != null && rewardRect == null;
      (save.parentData! as BoxParentData).offset = saveAt;
      if (wasHidden != _rewardHidden) markNeedsSemanticsUpdate();
      return;
    }

    // 最後手段（照片比收藏鈕還矮之類）：收藏鈕回右上，狀態只用它左側的空間、
    // 以省略號收尾；連最小的標籤都塞不下時直接裁切，確保圓上不會壓著字。
    _place(status, const Offset(_inset, _inset), beside);
    if (reward != null) _place(reward, Offset.zero, beside);
    _rewardHidden = reward != null;
    (save.parentData! as BoxParentData).offset = topRight;
    _chipClip = Rect.fromLTRB(0, 0, math.max(0.0, left), size.height);
    if (wasHidden != _rewardHidden) markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintChips(PaintingContext context, Offset offset) {
      final status = _status!;
      context.paintChild(status, offset + _offsetOf(status));
      final reward = _reward;
      if (reward != null && !_rewardHidden) {
        context.paintChild(reward, offset + _offsetOf(reward));
      }
    }

    final clip = _chipClip;
    if (clip == null) {
      _clipLayer.layer = null;
      paintChips(context, offset);
    } else {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        clip,
        paintChips,
        oldLayer: _clipLayer.layer,
      );
    }
    final save = _save!;
    context.paintChild(save, offset + _offsetOf(save));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // 收藏鈕畫在最上層，先測它。
    for (final child in [_save, if (!_rewardHidden) _reward, _status]) {
      if (child == null) continue;
      final hit = result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in children) {
      if (!_rewardHidden || child != _reward) visitor(child);
    }
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// 物品卡載入中的骨架；與 [FoundItemCard] 同尺寸，載入完成時不會跳動。
class ItemGridSkeleton extends StatelessWidget {
  const ItemGridSkeleton({super.key, this.columns = 2, this.rows = 2});
  final int columns;
  final int rows;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.neutral100,
    highlightColor: AppColors.neutral50,
    period: const Duration(milliseconds: 1400),
    child: Column(
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: c < columns - 1 ? 12 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 4.6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.neutral100,
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _bar(.85, 14),
                          const SizedBox(height: 8),
                          _bar(.6, 11),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _bar(double fraction, double height) => FractionallySizedBox(
    widthFactor: fraction,
    alignment: Alignment.centerLeft,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

/// 區塊標題：左標題、右說明或動作。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

/// 空狀態：角括號裡什麼都沒有，但把「下一步」交到使用者手上。
class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
    this.icon = Icons.search_off_rounded,
  });
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      children: [
        BracketMark(
          size: 88,
          color: AppColors.ink100,
          strokeWidth: 3,
          child: Icon(icon, size: 30, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink50,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(action!),
          ),
        ],
      ],
    ),
  );
}
