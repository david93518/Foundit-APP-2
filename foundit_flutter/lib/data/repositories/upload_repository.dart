import 'dart:io';

import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// 圖片 / 檔案上傳。後端: `POST /upload/image (multipart, field=file)` → 回傳完整 URL
abstract class UploadRepository {
  /// 上傳單張圖片，回傳可公開存取的 URL；失敗回傳 null
  Future<String?> uploadImage(File file);

  /// 平行上傳多張，失敗的會被跳過
  Future<List<String>> uploadImages(Iterable<File> files);
}

class MockUploadRepository implements UploadRepository {
  @override
  Future<String?> uploadImage(File file) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // 在 Mock 模式下回傳本地路徑，前端用 Image.file 也能顯示
    return file.path;
  }

  @override
  Future<List<String>> uploadImages(Iterable<File> files) async {
    final list = files.toList();
    return [for (final f in list) f.path];
  }
}

class RemoteUploadRepository implements UploadRepository {
  RemoteUploadRepository(this._api);
  final ApiClient _api;

  @override
  Future<String?> uploadImage(File file) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      });
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/upload/image',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data?['url']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> uploadImages(Iterable<File> files) async {
    final results = await Future.wait(files.map(uploadImage));
    return results.whereType<String>().toList();
  }
}
