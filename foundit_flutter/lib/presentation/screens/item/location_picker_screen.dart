import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/map_style_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/item.dart';
import '../../providers/core_providers.dart';

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

/// The initial camera position is never silently accepted as an item location.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
    this.tileProvider,
  });
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialQuery;
  final TileProvider? tileProvider;
  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  static const _center = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  LatLng? _picked;
  String _label = '';
  String? _message;
  bool _searching = false;
  bool _locating = false;
  int _generation = 0;
  List<LocationPickedResult> _results = [];

  @override
  void initState() {
    super.initState();
    if (Item.validPosition(widget.initialLatitude, widget.initialLongitude)) {
      _picked = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _label = widget.initialQuery?.trim() ?? '';
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _editQuery(String _) => setState(() {
    _generation++;
    _searching = false;
    _locating = false;
    _results = [];
    _picked = null;
    _label = '';
    _message = null;
  });

  Future<void> _find() async {
    final query = _search.text.trim();
    if (_searching || query.isEmpty) return;
    FocusScope.of(context).unfocus();
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _locating = false;
      _message = null;
      _results = [];
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/locations/search', query: {'q': query});
      if (!mounted || generation != _generation) return;
      final rows = response.data?['data'] as List? ?? [];
      final results = <LocationPickedResult>[];
      for (final row in rows.whereType<Map>()) {
        final lat = (row['latitude'] as num?)?.toDouble();
        final lng = (row['longitude'] as num?)?.toDouble();
        if (Item.validPosition(lat, lng)) {
          results.add(
            LocationPickedResult(
              latitude: lat!,
              longitude: lng!,
              address: row['label']?.toString() ?? query,
            ),
          );
        }
      }
      setState(() {
        _results = results;
        if (results.isEmpty) _message = '找不到地點。可補上縣市或完整校名，也可直接在地圖點選。';
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _message = '搜尋暫時無法使用，仍可在地圖上點選位置。');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  void _select(LatLng point, String label, {bool move = false}) {
    if (!Item.validPosition(point.latitude, point.longitude)) return;
    _generation++;
    setState(() {
      _picked = point;
      _label = label.trim();
      _message = null;
      _results = [];
      _searching = false;
      _locating = false;
    });
    FocusScope.of(context).unfocus();
    if (move) _map.move(point, 16);
  }

  Future<void> _locate() async {
    if (_locating) return;
    final generation = ++_generation;
    setState(() {
      _locating = true;
      _searching = false;
      _results = [];
    });
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted || generation != _generation) return;
    setState(() => _locating = false);
    if (result.isOk && result.position != null) {
      _select(result.position!, _search.text, move: true);
    } else {
      setState(() => _message = result.message);
    }
  }

  String get _selectedLabel => _label.isNotEmpty ? _label : '地圖標示位置';
  void _confirm() {
    final point = _picked;
    if (point == null || _searching || _locating) return;
    context.pop(
      LocationPickedResult(
        latitude: point.latitude,
        longitude: point.longitude,
        address: _selectedLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('確認地圖位置')),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        maxLength: 150,
                        textInputAction: TextInputAction.search,
                        onChanged: _editQuery,
                        onSubmitted: (_) => _find(),
                        decoration: const InputDecoration(
                          hintText: '輸入縣市、校名或地標',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '搜尋地點',
                      onPressed: _searching ? null : _find,
                      icon: _searching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
              if (_results.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('請選擇正確的地點，再確認地圖標記。'),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final place = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.address),
                        onTap: () {
                          _search.text = place.address;
                          _select(
                            LatLng(place.latitude, place.longitude),
                            place.address,
                            move: true,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              SizedBox(
                height: (constraints.maxHeight * .6).clamp(220.0, 520.0),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _picked ?? _center,
                        initialZoom: _picked == null ? 7 : 15,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: (_, point) => _select(point, _search.text),
                      ),
                      children: [
                        founditBaseMap(tileProvider: widget.tileProvider),
                        MarkerLayer(
                          markers: [
                            if (_picked != null)
                              Marker(
                                key: const ValueKey('confirmed-location-pin'),
                                point: _picked!,
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_on,
                                  size: 44,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 12,
                      bottom: 26,
                      child: FilledButton.tonalIcon(
                        onPressed: _locating ? null : _locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(_locating ? '定位中…' : '我的位置'),
                      ),
                    ),
                    const Positioned(
                      left: 8,
                      bottom: 6,
                      child: Text(
                        baseMapAttribution,
                        style: TextStyle(fontSize: 9, color: Color(0xFF444444)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _picked == null ? '尚未選擇位置' : _selectedLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _picked == null
                          ? '搜尋後選擇地點，或點選地圖上的大概位置；不需要公開私人住址。'
                          : '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: const Text(
                        '地點搜尋 © OpenStreetMap contributors',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _picked == null || _searching || _locating
                          ? null
                          : _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('使用此位置'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
