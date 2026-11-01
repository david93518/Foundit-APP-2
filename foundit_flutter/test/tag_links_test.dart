import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/services/tag_links.dart';

void main() {
  const code = '8f0c1f8e-2a3b-4c5d-9e6f-0a1b2c3d4e5f';

  test('accepts the sticker URL and the landing page button', () {
    expect(tagCodeFromLink(Uri.parse('https://api.foundit.tw/qr/$code')), code);
    expect(
      tagCodeFromLink(Uri.parse('https://api.foundit.tw/qr/$code/')),
      code,
    );
    expect(tagCodeFromLink(Uri.parse('foundit://qr/$code')), code);
  });

  test(
    'ignores every other link so web pages cannot open arbitrary screens',
    () {
      for (final link in [
        'https://evil.example/qr/$code',
        'http://api.foundit.tw/qr/$code',
        'https://api.foundit.tw/chat/$code',
        'https://api.foundit.tw/qr/scan',
        'https://api.foundit.tw/qr/$code/extra',
        'foundit://chat/$code',
        'foundit://qr/../chat/abc',
        'foundit://qr/short',
        'com.googleusercontent.apps.123:/oauthredirect?code=abc',
      ]) {
        expect(tagCodeFromLink(Uri.parse(link)), isNull, reason: link);
      }
    },
  );

  test('validates codes passed to the scan route', () {
    expect(tagCodeOrNull(code), code);
    expect(tagCodeOrNull(' $code '), code);
    expect(tagCodeOrNull(null), isNull);
    expect(tagCodeOrNull('<script>'), isNull);
  });
}
