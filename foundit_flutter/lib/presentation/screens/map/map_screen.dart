import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/item_repository.dart';
import '../../providers/items_provider.dart';
import '../../widgets/type_badge.dart';

/// 探索地圖頁 — 接 backend `/items?lat=&lng=&radius=`，搭配 GPS 與類型篩選
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _defaultCenter = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  late final MapController _mapController;
  ItemType? _typeFilter; // null = 全部
  Item? _selected;
  LatLng? _userLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // 進頁面後嘗試靜默取一次 GPS（不打擾，沒拿到就停在預設）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateMe(silent: true);
    });
  }

  ItemFilter get _filter => ItemFilter(
        type: _typeFilter,
        // 範圍給大一點，避免實機在台北 → 還沒移動就 0 件
        lat: _userLocation?.latitude,
        lng: _userLocation?.longitude,
        radius: _userLocation == null ? null : AppConstants.nearbyRadiusKm * 6,
        pageSize: 100,
      );

  Future<void> _locateMe({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);

    final svc = ref.read(locationServiceProvider);
    final res = await svc.currentPosition();

    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.isOk) _userLocation = res.position;
    });

    if (res.isOk) {
      Haptics.light();
      _mapController.move(res.position!, 16);
    } else if (!silent) {
      AppSnackbar.error(context, res.message);
    }
  }

  /// 同一座標的多個 marker → 給予環形微小偏移，避免完全重疊
  List<_MarkerData> _layoutMarkers(List<Item> items) {
    final buckets = <String, List<Item>>{};
    for (final it in items) {
      if (it.latitude == 0 && it.longitude == 0) continue; // 過濾沒填位置的
      final key =
          '${it.latitude.toStringAsFixed(5)}_${it.longitude.toStringAsFixed(5)}';
      buckets.putIfAbsent(key, () => []).add(it);
    }

    final out = <_MarkerData>[];
    buckets.forEach((_, group) {
      if (group.length == 1) {
        out.add(_MarkerData(group.first, LatLng(group.first.latitude, group.first.longitude)));
        return;
      }
      const r = 0.00012; // ≈ 13m
      for (var i = 0; i < group.length; i++) {
        final ang = (2 * math.pi / group.length) * i;
        out.add(
          _MarkerData(
            group[i],
            LatLng(
              group[i].latitude + r * math.sin(ang),
              group[i].longitude + r * math.cos(ang),
            ),
          ),
        );
      }
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(itemsProvider(_filter));

    final items = asyncItems.maybeWhen(
      data: (list) => list.where((i) => i.status != ItemStatus.resolved).toList(),
      orElse: () => const <Item>[],
    );
    final markers = _layoutMarkers(items);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _defaultCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.foundit',
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 28,
                      height: 28,
                      point: _userLocation!,
                      child: const _UserDot(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: markers
                    .map(
                      (m) => Marker(
                        width: 44,
                        height: 56,
                        point: m.point,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () {
                            Haptics.light();
                            setState(() => _selected = m.item);
                            _mapController.move(
                              LatLng(m.item.latitude, m.item.longitude),
                              math.max(_mapController.camera.zoom, 15),
                            );
                          },
                          child: _MapPin(
                            isLost: m.item.type == ItemType.lost,
                            selected: _selected?.id == m.item.id,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),

          _TopBar(
            keyword: '',
            onBack: () => context.pop(),
            onSearchTap: () => context.push('/search'),
            onLocateMe: () => _locateMe(silent: false),
            locating: _locating,
          ),

          _FilterBar(
            value: _typeFilter,
            countAll: items.length,
            countLost: items.where((i) => i.type == ItemType.lost).length,
            countFound: items.where((i) => i.type == ItemType.found).length,
            onChanged: (v) {
              Haptics.select();
              setState(() {
                _typeFilter = v;
                _selected = null;
              });
            },
          ),

          // 載入指示
          if (asyncItems.isLoading)
            const Positioned(
              top: 170,
              right: 20,
              child: _MapPill(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

          // 錯誤顯示
          if (asyncItems.hasError && !asyncItems.isLoading)
            Positioned(
              top: 170,
              left: 16,
              right: 16,
              child: _ErrorCard(
                onRetry: () => ref.invalidate(itemsProvider(_filter)),
              ),
            ),

          // 空狀態（已載入但 0 件）
          if (asyncItems.hasValue && items.isEmpty && !asyncItems.isLoading)
            const Positioned(
              top: 180,
              left: 16,
              right: 16,
              child: _EmptyHint(),
            ),

          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _BottomPreview(
                item: _selected!,
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkerData {
  final Item item;
  final LatLng point;
  const _MarkerData(this.item, this.point);
}

// ─────────────────────────────────────────────────────────────────
// 子元件
// ─────────────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  const _MapPin({required this.isLost, required this.selected});
  final bool isLost;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = isLost ? AppColors.lost : AppColors.found;
    final size = selected ? 36.0 : 28.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (selected)
            Container(
              width: size + 18,
              height: size + 18,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isLost
                  ? Icons.help_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: selected ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onSearchTap,
    required this.onLocateMe,
    required this.keyword,
    required this.locating,
  });
  final VoidCallback onBack;
  final VoidCallback onSearchTap;
  final VoidCallback onLocateMe;
  final String keyword;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _Glass(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: AppRadius.allMd,
                  child: InkWell(
                    onTap: onSearchTap,
                    borderRadius: AppRadius.allMd,
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.allMd,
                        boxShadow: AppShadows.md,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            keyword.isEmpty
                                ? '搜尋物品、地點或關鍵字'
                                : keyword,
                            style: TextStyle(
                              color: keyword.isEmpty
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Glass(
                icon: locating
                    ? Icons.gps_not_fixed_rounded
                    : Icons.my_location_rounded,
                loading: locating,
                onTap: onLocateMe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: loading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.md,
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.countAll,
    required this.countLost,
    required this.countFound,
    required this.onChanged,
  });
  final ItemType? value;
  final int countAll;
  final int countLost;
  final int countFound;
  final ValueChanged<ItemType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _Chip(
                label: '全部',
                count: countAll,
                color: AppColors.textPrimary,
                selected: value == null,
                onTap: () => onChanged(null),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: '遺失',
                count: countLost,
                color: AppColors.lost,
                dotColor: AppColors.lost,
                selected: value == ItemType.lost,
                onTap: () => onChanged(ItemType.lost),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: '拾獲',
                count: countFound,
                color: AppColors.found,
                dotColor: AppColors.found,
                selected: value == ItemType.found,
                onTap: () => onChanged(ItemType.found),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });
  final String label;
  final int count;
  final Color color;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : Colors.white;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: bg,
      borderRadius: AppRadius.allRound,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allRound,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.allRound,
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.neutral100,
                  borderRadius: AppRadius.allRound,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.allRound,
        boxShadow: AppShadows.md,
      ),
      child: child,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.allLg,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppRadius.allLg,
          boxShadow: AppShadows.md,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.lost,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '無法載入附近物品，請檢查網路或重試',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: AppRadius.allLg,
          boxShadow: AppShadows.md,
        ),
        child: const Row(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '附近還沒有物品被張貼。試試切換類型，或是把你看到的東西丟上來幫助別人。',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPreview extends StatelessWidget {
  const _BottomPreview({required this.item, required this.onClose});
  final Item item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        child: InkWell(
          onTap: () => context.push('/item/${item.id}', extra: item),
          borderRadius: AppRadius.allLg,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.allLg,
              boxShadow: AppShadows.lg,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.allMd,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: item.images.isEmpty
                        ? Container(
                            color: AppColors.neutral100,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.images.first,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.neutral100),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.neutral100,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TypeBadge(type: item.type, dense: true),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.locationName.isEmpty ? '未填寫地點' : item.locationName} · ${DateFormatter.relative(item.lostAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
