import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// 防丟牌代碼的格式（與後端 scanByCode 相同）：只含英數與連字號。
String? tagCodeOrNull(String? code) {
  final value = code?.trim() ?? '';
  return RegExp(r'^[A-Za-z0-9-]{8,80}$').hasMatch(value) ? value : null;
}

/// 只接受兩種外部連結，其餘一律忽略（不讓網頁或其他 App 把使用者帶到 App 內任意頁面）：
/// - 貼紙網址 `https://<API 網域>/qr/<code>`（手機相機掃描，經 Universal Links / App Links 開進來）
/// - 落地頁按鈕 `foundit://qr/<code>`
String? tagCodeFromLink(Uri uri) {
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (uri.scheme == 'foundit') {
    if (uri.host != 'qr' || segments.length != 1) return null;
    return tagCodeOrNull(segments.single);
  }
  if (uri.scheme != 'https' || !_tagHosts.contains(uri.host)) return null;
  if (segments.length != 2 || segments.first != 'qr') return null;
  return tagCodeOrNull(segments.last);
}

final Set<String> _tagHosts = {
  'api.foundit.tw',
  Uri.parse(AppConstants.socketHost).host,
};

/// 監聽 App 被貼紙連結打開（冷啟動與執行中都算），交出驗證過的代碼。
class TagLinks {
  final _codes = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;

  Stream<String> get codes => _codes.stream;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void start() {
    if (!supported || _sub != null) return;
    // app_links 6 的 uriLinkStream 也會送出冷啟動時的那個連結。
    _sub = AppLinks().uriLinkStream.listen((uri) {
      final code = tagCodeFromLink(uri);
      if (code != null) _codes.add(code);
    }, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
    _codes.close();
  }
}
