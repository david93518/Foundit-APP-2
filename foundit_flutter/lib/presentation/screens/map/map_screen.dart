import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/map_style_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/item.dart';
import '../../providers/items_provider.dart';
import '../../widgets/foundit_ui.dart';

/// 全螢幕地圖：篩選、筆數與「我的位置」浮在地圖上，整頁不捲動。
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.tileProvider});

  /// 測試時注入的圖磚來源；正式版走網路圖磚。
  final TileProvider? tileProvider;
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

const _overview = LatLng(23.7, 120.95);
const _overviewZoom = 7.0;

/// 臺灣本島＋澎湖；上方留給浮動篩選列，避免北部標記被蓋住。
final _taiwanFit = CameraFit.bounds(
  bounds: LatLngBounds(const LatLng(21.85, 119.4), const LatLng(25.35, 122.05)),
  padding: const EdgeInsets.fromLTRB(16, 128, 16, 90),
);
// 底圖永遠是亮色，標記與版權字樣固定用亮色模式的值。
final _lostMarker = AppColors.neutral800.light;

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  ItemType? _type;
  Item? _selected;
  LatLng? _myLocation;
  bool _locating = false;
  String? _locationError;
  bool _mapReady = false;
  bool _userMoved = false;
  Size? _fittedSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate(automatic: true);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locate({bool automatic = false}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      if (!automatic) _userMoved = false;
    });
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.isOk) _myLocation = result.position;
      if (!result.isOk) _locationError = result.message;
    });
    if (result.isOk && _mapReady && !_userMoved) {
      _mapController.move(result.position!, 15);
    }
  }

  void _showAll(List<Item> items) {
    setState(() => _selected = null);
    if (items.isEmpty) {
      _mapController.fitCamera(_taiwanFit);
      return;
    }
    if (items.length == 1) {
      _mapController.move(
        LatLng(items.first.latitude, items.first.longitude),
        14,
      );
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          for (final item in items) LatLng(item.latitude, item.longitude),
        ],
        padding: const EdgeInsets.fromLTRB(48, 140, 48, 120),
        maxZoom: 15,
      ),
    );
  }

  /// 地圖尺寸改變（首次排版、旋轉、分割畫面）而使用者還沒操作時，重新套用全臺總覽，
  /// 避免第一次排版尺寸異常時卡在最小縮放。
  void _refitOverviewIfResized(Size size) {
    if (!size.isFinite || size.isEmpty || size == _fittedSize) return;
    _fittedSize = size;
    if (!_mapReady || _userMoved || _myLocation != null || _selected != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_userMoved && _myLocation == null) {
        _mapController.fitCamera(_taiwanFit);
      }
    });
  }

  Future<void> _showUnlocated(List<Item> items) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .65,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              '${items.length} 件尚未標示位置',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('這些刊登只有地點文字。開啟自己的刊登後，可按「補上地圖位置」。'),
            const SizedBox(height: 16),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_off_outlined),
                title: Text(item.title),
                subtitle: Text(item.locationName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheet, item.id),
              ),
          ],
        ),
      ),
    );
    if (id != null && mounted) await context.push('/item/$id');
    if (mounted) ref.invalidate(mapItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(mapItemsProvider(_type));
    final items = (result.asData?.value ?? const <Item>[])
        .where(
          (item) => item.status == ItemStatus.active && item.hasMapPosition,
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        _refitOverviewIfResized(constraints.biggest);
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _overview,
                  initialZoom: _overviewZoom,
                  initialCameraFit: _taiwanFit,
                  minZoom: 5,
                  maxZoom: 19,
                  backgroundColor: const Color(0xFFF3F1EC),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    if (_myLocation != null && !_userMoved) {
                      _mapController.move(_myLocation!, 15);
                    } else if (!_userMoved) {
                      _mapController.fitCamera(_taiwanFit);
                    }
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) _userMoved = true;
                  },
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  founditBaseMap(tileProvider: widget.tileProvider),
                  MarkerLayer(
                    markers: [
                      for (final item in items) _marker(item),
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          key: const ValueKey('map-user-position'),
                          width: 26,
                          height: 26,
                          child: Tooltip(
                            message: '我的位置',
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F6FDB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x332F6FDB),
                                    blurRadius: 0,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 篩選與狀態（窄螢幕自動換行）
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FloatingCard(
                    padding: const EdgeInsets.all(4),
                    // 大字級的窄螢幕放不下三個按鈕時改為橫向捲動。
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in <(ItemType?, String)>[
                            (null, '全部'),
                            (ItemType.found, '待認領'),
                            (ItemType.lost, '協尋中'),
                          ])
                            _FilterButton(
                              label: option.$2,
                              selected: _type == option.$1,
                              dotColor: switch (option.$1) {
                                ItemType.found => AppColors.primary,
                                ItemType.lost => _lostMarker,
                                null => null,
                              },
                              onTap: () => setState(() {
                                _type = option.$1;
                                _selected = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _status(result, items),
                ],
              ),
            ),
            // 右下：顯示全部 / 我的位置
            if (_selected == null)
              Positioned(
                right: 12,
                left: 12,
                bottom: 34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_locationError != null) ...[
                      _FloatingCard(
                        key: const ValueKey('map-location-error'),
                        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _locationError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '關閉定位提示',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _locationError = null),
                              icon: const Icon(Icons.close_rounded, size: 16),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _FloatingCard(
                          radius: 24,
                          child: IconButton(
                            tooltip: '更新地圖物品',
                            onPressed: result.isLoading
                                ? null
                                : () => ref.invalidate(mapItemsProvider),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                          ),
                        ),
                        if (items.isNotEmpty) ...[
                          _FloatingCard(
                            radius: 24,
                            child: IconButton(
                              tooltip: '顯示全部物品',
                              onPressed: () => _showAll(items),
                              icon: const Icon(
                                Icons.zoom_out_map_rounded,
                                size: 20,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _FloatingCard(
                      radius: 24,
                      child: TextButton.icon(
                        onPressed: _locating ? null : _locate,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(48, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _locating ? '定位中…' : '我的位置',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 地圖資料來源（OSM 授權要求可見）
            Positioned(
              left: 8,
              bottom: 6,
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(baseMapAttributionUrl)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    baseMapAttribution,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary.light,
                    ),
                  ),
                ),
              ),
            ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: wide ? null : 12,
                bottom: 28,
                width: wide ? 380 : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight - 140,
                  ),
                  child: SingleChildScrollView(
                    child: _SelectedItem(
                      item: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _status(AsyncValue<List<Item>> result, List<Item> items) {
    if (result.isLoading) {
      return const _FloatingCard(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text('正在尋找物品…', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    if (result.hasError) {
      return _FloatingCard(
        padding: const EdgeInsets.fromLTRB(12, 2, 2, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 16,
              color: AppColors.error600,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                '物品暫時載入不了',
                style: TextStyle(fontSize: 12, color: AppColors.error600),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(mapItemsProvider(_type)),
              child: const Text('重試', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
    final unlocated = (result.asData?.value ?? const <Item>[])
        .where(
          (item) => item.status == ItemStatus.active && !item.hasMapPosition,
        )
        .toList();
    if (unlocated.isEmpty) {
      return _FloatingCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          items.isEmpty ? '這裡還沒有標記' : '${items.length} 件物品已標示位置',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    return _FloatingCard(
      child: InkWell(
        onTap: unlocated.isEmpty ? null : () => _showUnlocated(unlocated),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            unlocated.isNotEmpty
                ? '${items.length} 件已標示 · ${unlocated.length} 件待補位置 ›'
                : items.isEmpty
                ? '這裡還沒有標記'
                : '${items.length} 件物品已標示位置',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Marker _marker(Item item) {
    final selected = _selected?.id == item.id;
    final color = item.type == ItemType.found
        ? AppColors.primary.light
        : _lostMarker;
    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: 46,
      height: 54,
      alignment: Alignment.topCenter,
      child: Tooltip(
        message: '${itemStatusLabel(item)}・${item.title}',
        child: Semantics(
          button: true,
          label: '查看 ${item.title}',
          child: GestureDetector(
            key: ValueKey('map-item-${item.id}'),
            onTap: () {
              setState(() => _selected = item);
              _mapController.move(
                LatLng(item.latitude, item.longitude),
                _mapController.camera.zoom < 13
                    ? 13
                    : _mapController.camera.zoom,
              );
            },
            child: AnimatedScale(
              scale: selected ? 1.15 : 1,
              alignment: Alignment.bottomCenter,
              duration: const Duration(milliseconds: 160),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33282B30),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      item.type == ItemType.found
                          ? Icons.inventory_2_outlined
                          : Icons.search_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(12, 8),
                    painter: _PinTail(color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  _PinTail(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTail old) => old.color != color;
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 14,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 2,
    shadowColor: const Color(0x33282B30),
    borderRadius: BorderRadius.circular(radius),
    child: Padding(padding: padding, child: child),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.textPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.onInk : dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.onInk : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SelectedItem extends StatelessWidget {
  const _SelectedItem({required this.item, required this.onClose});
  final Item item;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    elevation: 4,
    shadowColor: const Color(0x33282B30),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/item/${item.id}', extra: item),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 84,
                height: 96,
                child: ItemPhoto(item.images.firstOrNull),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      StatusTag(item),
                      const Spacer(),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          tooltip: '關閉物品預覽',
                          padding: EdgeInsets.zero,
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.locationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text(
                        '查看詳情',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
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
