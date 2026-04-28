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
/// 3. 取得目前座標（含逾時 fallback 到 last known）
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

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
      } catch (_) {
        // 主流程失敗 → 用 last known，至少給個位置
        pos = await Geolocator.getLastKnownPosition();
        if (pos == null) {
          return const LocationResult(LocationResultCode.timeout);
        }
      }

      return LocationResult(
        LocationResultCode.ok,
        LatLng(pos.latitude, pos.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationResultCode.unknown);
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((_) => const LocationService());
