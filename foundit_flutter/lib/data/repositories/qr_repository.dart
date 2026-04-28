import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/qr_item.dart';

abstract class QrRepository {
  Future<List<QrItemModel>> listMine();
  Future<QrItemModel> generate({required String name, String description = ''});
  Future<void> remove(String id);
  Future<QrScanResult> scanByCode(String code);
}

class RemoteQrRepository implements QrRepository {
  RemoteQrRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<QrItemModel>> listMine() async {
    final res = await _api.get<Map<String, dynamic>>('/qr/items');
    final raw = res.data?['data'] as List? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(QrItemModel.fromJson)
        .toList();
  }

  @override
  Future<QrItemModel> generate({
    required String name,
    String description = '',
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/qr/generate',
      data: {'name': name, 'description': description},
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/qr/generate'),
        message: '建立 QR 失敗',
      );
    }
    return QrItemModel.fromJson(data);
  }

  @override
  Future<void> remove(String id) async {
    await _api.delete<Map<String, dynamic>>('/qr/items/$id');
  }

  @override
  Future<QrScanResult> scanByCode(String code) async {
    final res = await _api.get<Map<String, dynamic>>('/qr/scan/$code');
    final body = res.data;
    if (body == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/qr/scan/$code'),
        message: 'QR 內容為空',
      );
    }
    return QrScanResult.fromJson(body);
  }
}

class MockQrRepository implements QrRepository {
  final List<QrItemModel> _items = [];

  @override
  Future<List<QrItemModel>> listMine() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_items);
  }

  @override
  Future<QrItemModel> generate({
    required String name,
    String description = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final code = 'mock-${DateTime.now().microsecondsSinceEpoch}';
    final item = QrItemModel(
      id: code,
      userId: 'me',
      name: name,
      description: description,
      qrCode: 'http://localhost:3000/qr/$code',
      createdAt: DateTime.now(),
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<QrScanResult> scanByCode(String code) async {
    throw UnimplementedError('Mock 不支援 scan');
  }
}
