import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 列印用固定配色：不跟深色模式切換，確保任何相機都掃得到。
const _ink = Color(0xFF282B30);
const _muted = Color(0xFF6B6F76);
const _paper = Color(0xFFFFFFFF);

/// 把防丟牌畫成可列印的 PNG：品牌、QR、物品名稱，以及給撿到的人的提示。
Future<Uint8List> renderQrTagPng({
  required String data,
  required String name,
  double width = 1080,
}) async {
  final padding = width * .09;
  final qrSize = width - padding * 2;
  final contentWidth = qrSize;

  TextPainter text(String value, double size, Color color, FontWeight weight,
      {double spacing = 0, int maxLines = 2}) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'NotoSansTC',
          fontSize: size,
          height: 1.35,
          color: color,
          fontWeight: weight,
          letterSpacing: spacing,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: contentWidth);
  }

  final brand = text('FOUND !T', width * .036, _ink, FontWeight.w700,
      spacing: width * .006, maxLines: 1);
  final title = text(name.trim().isEmpty ? '我的防丟牌' : name.trim(),
      width * .056, _ink, FontWeight.w700);
  final hint = text('撿到了嗎？打開 FOUND !T 掃描這個 QR，\n就能直接傳訊息給物主。',
      width * .032, _muted, FontWeight.w400);

  final gap = width * .04;
  final height = padding +
      brand.height +
      gap +
      qrSize +
      gap * 1.2 +
      title.height +
      gap * .5 +
      hint.height +
      padding;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = _paper);

  var y = padding;
  void paintCentered(TextPainter painter) {
    painter.paint(canvas, Offset((width - painter.width) / 2, y));
    y += painter.height;
  }

  paintCentered(brand);
  y += gap;
  canvas.save();
  canvas.translate(padding, y);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: _ink,
    ),
  ).paint(canvas, Size.square(qrSize));
  canvas.restore();
  y += qrSize + gap * 1.2;
  paintCentered(title);
  y += gap * .5;
  paintCentered(hint);

  final image = await recorder
      .endRecording()
      .toImage(width.round(), height.ceil());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('QR 圖片轉檔失敗');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
