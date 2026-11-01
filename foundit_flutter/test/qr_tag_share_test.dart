import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/core/utils/qr_tag_image.dart';
import 'package:foundit/presentation/screens/qr/qr_scan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets('printable tag is a PNG wide enough to scan after printing', (
    tester,
  ) async {
    final Uint8List bytes = (await tester.runAsync(
      () => renderQrTagPng(
        data: 'https://api.foundit.tw/qr/8f0c1f8e-2a3b-4c5d-9e6f-0a1b2c3d4e5f',
        name: '有綠色恐龍吊飾與藍色繩結的深棕色皮革鑰匙包，還掛著一個很長的名牌',
      ),
    ))!;
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final image = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }))!;
    expect(image.width, 1080);
    expect(image.height, greaterThan(image.width));
    image.dispose();
  });

  testWidgets('owner scanning their own tag is not offered a chat with themselves', (
    tester,
  ) async {
    var contacted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: QrScanResultSheet(
            itemName: '藍色後背包',
            ownerName: '物主',
            isOwnTag: true,
            onContact: () => contacted = true,
            onContinue: () {},
          ),
        ),
      ),
    );
    expect(find.text('傳訊息給物主'), findsNothing);
    expect(find.textContaining('這是你自己的防丟牌'), findsOneWidget);
    expect(find.text('繼續掃描'), findsOneWidget);
    expect(contacted, isFalse);
  });

  testWidgets('a finder can start a chat from the scan result', (tester) async {
    var contacted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: QrScanResultSheet(
            itemName: '藍色後背包',
            ownerName: '物主',
            onContact: () => contacted = true,
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('qr-contact-owner')));
    expect(contacted, isTrue);
  });
}
