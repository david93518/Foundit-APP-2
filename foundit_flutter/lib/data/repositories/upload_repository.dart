import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../api/api_client.dart';

/// 圖片 / 檔案上傳。後端: `POST /upload/image (multipart, field=file)` → 回傳完整 URL
abstract class UploadRepository {
  /// 上傳單張圖片，回傳可公開存取的 URL；失敗回傳 null
  Future<String?> uploadImage(File file);

  /// 跨平台上傳；網頁不依賴本地檔案路徑。
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  });

  /// 平行上傳多張，失敗的會被跳過
  Future<List<String>> uploadImages(Iterable<File> files);
}

class MockUploadRepository implements UploadRepository {
  @override
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  }) async {
    return 'data:${_imageMime(filename, mimeType)};base64,${base64Encode(bytes)}';
  }

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

/// 伺服器明確拒絕這張圖（例如數量上限、檔案太大、格式不符），訊息可直接顯示。
class UploadRejected implements Exception {
  const UploadRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 伺服器有回應錯誤時轉成 [UploadRejected]；連線問題維持回傳 null。
Never _rejectIfAnswered(DioException error) {
  final status = error.response?.statusCode;
  if (status == 413) throw const UploadRejected('照片太大，請選擇 8 MB 以下的照片。');
  throw UploadRejected(apiErrorMessage(error) ?? '照片無法上傳，請換一張照片再試。');
}

class RemoteUploadRepository implements UploadRepository {
  RemoteUploadRepository(this._api);
  final ApiClient _api;

  @override
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(_imageMime(filename, mimeType)),
        ),
      });
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/upload/image',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data?['url']?.toString();
    } on DioException catch (error) {
      if (error.response != null && error.response!.statusCode != 401) {
        _rejectIfAnswered(error);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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

String _imageMime(String filename, String? supplied) {
  if (supplied != null && supplied.startsWith('image/')) return supplied;
  final extension = filename.toLowerCase().split('.').last;
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
}
