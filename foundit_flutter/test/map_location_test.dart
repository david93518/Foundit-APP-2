import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:foundit/data/api/api_client.dart';
import 'package:foundit/presentation/screens/item/location_picker_screen.dart';
import 'package:foundit/core/services/location_service.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/items_provider.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/presentation/screens/map/map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Location extends LocationService {
  _Location(this.result);
  Future<LocationResult> result;
  int calls = 0;
  @override
  Future<LocationResult> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) {
    calls++;
    return result;
  }
}

class _Tiles extends TileProvider {
  _Tiles(this.bytes);
  final Uint8List bytes;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

void main() {
  late Uint8List bytes;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFFF3F1EC), BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });

  Future<void> mount(WidgetTester tester, _Location service) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(true),
          locationServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: MapScreen(tileProvider: _Tiles(bytes))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unlocated listings are visible as a list without fabricated pins',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026);
      Item item(String id, {double lat = 0, double lng = 0}) => Item(
        id: id,
        type: ItemType.found,
        title: id,
        category: '其他',
        latitude: lat,
        longitude: lng,
        locationName: '成大',
        lostAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final rows = [
        item('已定位', lat: 24.79, lng: 120.99),
        item('小波'),
        item('烤肉串'),
        item('灰貓'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(
              _Location(
                Future.value(
                  const LocationResult(LocationResultCode.permissionDenied),
                ),
              ),
            ),
            mapItemsProvider.overrideWith((ref, type) async => rows),
          ],
          child: MaterialApp(
            home: Scaffold(body: MapScreen(tileProvider: _Tiles(bytes))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 件已標示 · 3 件待補位置 ›'), findsOneWidget);
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers, hasLength(1));
      await tester.tap(find.text('1 件已標示 · 3 件待補位置 ›'));
      await tester.pumpAndSettle();
      expect(find.text('小波'), findsOneWidget);
      expect(find.text('烤肉串'), findsOneWidget);
      expect(find.text('灰貓'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typing a name never accepts the default center; search result must be selected',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(prefs);
      var searches = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            searches++;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'latitude': 22.998,
                      'longitude': 120.217,
                      'label': '國立成功大學',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(
              initialQuery: '成大',
              tileProvider: _Tiles(bytes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FilledButton confirm() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '使用此位置'),
      );
      expect(confirm().onPressed, isNull);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), '台南市 成大');
      await tester.pump(const Duration(seconds: 2));
      expect(searches, 0);
      await tester.tap(find.byTooltip('搜尋地點'));
      await tester.pumpAndSettle();
      expect(searches, 1);
      expect(confirm().onPressed, isNull);
      await tester.tap(find.text('國立成功大學'));
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNotNull);
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point,
        const LatLng(22.998, 120.217),
      );
      await tester.enterText(find.byType(TextField), '另一個地方');
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNull);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'location confirmation remains reachable with large text and keyboard',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final size in [
        const Size(320, 568),
        const Size(844, 390),
        const Size(768, 1024),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              locationServiceProvider.overrideWithValue(
                _Location(
                  Future.value(
                    const LocationResult(
                      LocationResultCode.ok,
                      LatLng(22.998, 120.217),
                    ),
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 200),
                ),
                child: child!,
              ),
              home: LocationPickerScreen(
                initialQuery: '成大',
                tileProvider: _Tiles(bytes),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('我的位置'));
        await tester.tap(find.text('我的位置'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('使用此位置'));
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '使用此位置'))
              .onPressed,
          isNotNull,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '$size at 200 percent text',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'opening map uses current position, filtering does not request it again',
    (tester) async {
      const position = LatLng(22.9999, 120.227);
      final service = _Location(
        Future.value(const LocationResult(LocationResultCode.ok, position)),
      );
      await mount(tester, service);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController!.camera.center, position);
      expect(map.mapController!.camera.zoom, 15);
      expect(find.byKey(const ValueKey('map-user-position')), findsOneWidget);
      await tester.tap(find.text('待認領'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(map.mapController!.camera.center, position);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied permission keeps overview and allows a fresh retry', (
    tester,
  ) async {
    final service = _Location(
      Future.value(const LocationResult(LocationResultCode.permissionDenied)),
    );
    await mount(tester, service);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    // 沒有定位時維持全臺總覽。
    final overview = map.mapController!.camera;
    expect(overview.center.latitude, inInclusiveRange(22.5, 24.5));
    expect(overview.center.longitude, inInclusiveRange(120.0, 121.8));
    expect(overview.zoom, inInclusiveRange(6.5, 9));
    expect(find.byKey(const ValueKey('map-location-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-user-position')), findsNothing);
    service.result = Future.value(
      const LocationResult(LocationResultCode.ok, LatLng(24.15, 120.68)),
    );
    await tester.tap(find.text('我的位置'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(map.mapController!.camera.center, const LatLng(24.15, 120.68));
    expect(find.byKey(const ValueKey('map-location-error')), findsNothing);
  });

  testWidgets('overview refits when the first layout size was too small', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(120, 160);
    final service = _Location(
      Future.value(const LocationResult(LocationResultCode.permissionDenied)),
    );
    await mount(tester, service);
    // 過小的暫態尺寸本來就放不下浮動按鈕，只驗證之後的正常尺寸。
    tester.takeException();
    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.zoom, inInclusiveRange(6.5, 9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late location result after leaving map is safe', (tester) async {
    final completion = Completer<LocationResult>();
    final service = _Location(completion.future);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(true),
          locationServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(body: MapScreen(tileProvider: _Tiles(bytes))),
        ),
      ),
    );
    await tester.pump();
    expect(service.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(
      const LocationResult(LocationResultCode.ok, LatLng(22.6, 120.3)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
