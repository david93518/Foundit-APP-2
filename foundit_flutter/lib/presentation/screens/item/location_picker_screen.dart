import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/map_style_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/haptics.dart';

/// 地圖選點 + 地址搜尋頁面
///
/// 使用 OpenStreetMap (flutter_map) + Nominatim 免費 geocoding。
/// - 上方：搜尋框（forward geocoding：地址 → 座標）
/// - 中間：地圖；點地圖任意位置即可選點
/// - 下方：當前選擇的座標 / 地址名稱（reverse geocoding）
/// - 右下：「使用我目前位置」浮動按鈕
///
/// 確認後回傳 [LocationPickResult]
class LocationPickedResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickedResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialQuery;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  late final MapController _mapController;
  late final TextEditingController _searchCtrl;

  static const _defaultCenter = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  LatLng _picked = _defaultCenter;
  String _address = '';
  bool _searching = false;
  bool _reversing = false;

  List<_NominatimSuggestion> _suggestions = [];
  Timer? _debounce;

  // Nominatim 公開 API（免費，需帶 User-Agent / Referer）
  // 服務條款：https://operations.osmfoundation.org/policies/nominatim/
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'foundit-app/1.0 (contact: support@foundit.com.tw)';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _picked = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }

    // 進頁面時：若已有座標就 reverse；否則若有 query 就 forward
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        await _reverseGeocode(_picked);
      } else if ((widget.initialQuery ?? '').trim().isNotEmpty) {
        await _searchAddress(widget.initialQuery!.trim());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(q);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'Accept-Language': 'zh-TW,zh,en',
        },
      ));
      final res = await dio.get<dynamic>(
        '$_nominatim/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 8,
          'addressdetails': 1,
        },
      );
      final list = (res.data is String)
          ? (jsonDecode(res.data as String) as List<dynamic>)
          : (res.data as List<dynamic>);
      if (!mounted) return;
      setState(() {
        _suggestions = list
            .whereType<Map<String, dynamic>>()
            .map(_NominatimSuggestion.fromJson)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = []);
    }
  }

  Future<void> _searchAddress(String query) async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      await _fetchSuggestions(query);
      if (_suggestions.isNotEmpty) {
        _selectSuggestion(_suggestions.first);
      } else if (mounted) {
        AppSnackbar.error(context, '找不到「$query」');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSuggestion(_NominatimSuggestion s) {
    Haptics.select();
    final p = LatLng(s.lat, s.lon);
    setState(() {
      _picked = p;
      _address = s.displayName;
      _suggestions = [];
      _searchCtrl.text = s.displayName;
    });
    _mapController.move(p, 16);
    FocusScope.of(context).unfocus();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _reversing = true);
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'Accept-Language': 'zh-TW,zh,en',
        },
      ));
      final res = await dio.get<dynamic>(
        '$_nominatim/reverse',
        queryParameters: {
          'lat': p.latitude,
          'lon': p.longitude,
          'format': 'json',
          'addressdetails': 1,
          'zoom': 18,
        },
      );
      final data = (res.data is String)
          ? (jsonDecode(res.data as String) as Map<String, dynamic>)
          : (res.data as Map<String, dynamic>);
      final name = (data['display_name'] as String?) ?? '';
      if (!mounted) return;
      setState(() => _address = name);
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = '');
    } finally {
      if (mounted) setState(() => _reversing = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    if (!result.isOk || result.position == null) {
      AppSnackbar.error(context, result.message);
      return;
    }
    final p = result.position!;
    setState(() => _picked = p);
    _mapController.move(p, 16);
    await _reverseGeocode(p);
  }

  void _onMapTap(TapPosition _, LatLng p) {
    Haptics.select();
    setState(() => _picked = p);
    _reverseGeocode(p);
  }

  void _confirm() {
    if (_address.trim().isEmpty && _searchCtrl.text.trim().isEmpty) {
      AppSnackbar.error(context, '請選擇位置或輸入地點名稱');
      return;
    }
    final addr = _address.trim().isNotEmpty
        ? _address.trim()
        : _searchCtrl.text.trim();
    context.pop(LocationPickedResult(
      latitude: _picked.latitude,
      longitude: _picked.longitude,
      address: addr,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSearchBar(),
            if (_suggestions.isNotEmpty) _buildSuggestions(),
            Expanded(child: _buildMap()),
            _buildBottomCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              '選擇地點',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) _searchAddress(v.trim());
        },
        decoration: InputDecoration(
          hintText: '搜尋地址、車站、地標…',
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _suggestions = []);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.neutral100),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, size: 20),
            title: Text(
              s.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => _selectSuggestion(s),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _picked,
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
            onTap: _onMapTap,
          ),
          children: [
            founditBaseMap(),
            MarkerLayer(
              markers: [
                Marker(
                  point: _picked,
                  width: 60,
                  height: 60,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'use-current',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            onPressed: _useCurrentLocation,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        const Positioned(
          left: 8,
          bottom: 6,
          child: Text(
            baseMapAttribution,
            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('已選位置',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  )),
              const Spacer(),
              Text(
                '${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_reversing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
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
                  Text('解析地址中…', style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          else
            Text(
              _address.isEmpty ? '在地圖上點選或搜尋地點' : _address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded),
              label: const Text('使用此位置'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimSuggestion {
  final double lat;
  final double lon;
  final String displayName;

  const _NominatimSuggestion({
    required this.lat,
    required this.lon,
    required this.displayName,
  });

  factory _NominatimSuggestion.fromJson(Map<String, dynamic> j) {
    return _NominatimSuggestion(
      lat: double.tryParse('${j['lat']}') ?? 0,
      lon: double.tryParse('${j['lon']}') ?? 0,
      displayName: (j['display_name'] as String?) ?? '',
    );
  }
}
