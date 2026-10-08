import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// 取得使用者位置的結果 — 失敗時帶上錯誤碼，UI 可顯示對應提示
enum LocationResultCode {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationResult {
  final LocationResultCode code;
  final LatLng? position;

  const LocationResult(this.code, [this.position]);

  bool get isOk => code == LocationResultCode.ok && position != null;

  String get message {
    switch (code) {
      case LocationResultCode.ok:
        return '已取得位置';
      case LocationResultCode.serviceDisabled:
        return '請開啟手機的定位服務';
      case LocationResultCode.permissionDenied:
        return '請允許定位權限以使用此功能';
      case LocationResultCode.permissionDeniedForever:
        return '已永久拒絕定位權限，請至系統設定開啟';
      case LocationResultCode.timeout:
        return '定位逾時，請至空曠處再試';
      case LocationResultCode.unknown:
        return '取得位置失敗';
    }
  }
}

/// 簡單封裝 `geolocator`：
/// 1. 確認系統定位開關
/// 2. 主動請求權限
/// 3. 取得當下座標；不把上次位置當成目前位置。
class LocationService {
  const LocationService();

  Future<LocationResult> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationResultCode.serviceDisabled);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(LocationResultCode.permissionDenied);
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(LocationResultCode.permissionDeniedForever);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        LocationResultCode.ok,
        LatLng(pos.latitude, pos.longitude),
      );
    } on TimeoutException {
      return const LocationResult(LocationResultCode.timeout);
    } on PermissionDeniedException {
      return const LocationResult(LocationResultCode.permissionDenied);
    } on LocationServiceDisabledException {
      return const LocationResult(LocationResultCode.serviceDisabled);
    } catch (_) {
      return const LocationResult(LocationResultCode.unknown);
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (_) => const LocationService(),
);
