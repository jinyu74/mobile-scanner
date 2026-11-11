import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/pdf_builder.dart';
import 'package:mobile_scanner/save_service.dart';

Uint8List _jpg(int w, int h) => img.encodeJpg(
  img.Image(width: w, height: h)..clear(img.ColorRgb8(255, 255, 255)),
);

/// PDF 원문에서 "/Type /Page" 객체 수와 MediaBox 값을 읽는다.
({int pages, List<String> boxes}) _inspect(Uint8List pdf) {
  final text = String.fromCharCodes(pdf);
  final pages = RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length;
  final boxes = RegExp(r'/MediaBox\s*\[([^\]]*)\]')
      .allMatches(text)
      .map((m) => m.group(1)!.trim().split(RegExp(r'\s+')).join(' '))
      .toList();
  return (pages: pages, boxes: boxes);
}

void main() {
  test('페이지 수만큼 A4(595x842pt) 페이지를 만든다', () async {
    final pdf = await buildA4Pdf([
      _jpg(200, 283),
      _jpg(300, 200),
      _jpg(100, 100),
    ]);
    final info = _inspect(pdf);

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(info.pages, 3);
    expect(info.boxes, isNotEmpty);
    for (final box in info.boxes) {
      final v = box.split(' ').map(double.parse).toList();
      expect(v[2] - v[0], closeTo(595.28, 0.5));
      expect(v[3] - v[1], closeTo(841.89, 0.5));
    }
  });

  test('JPG를 PNG로 바꾸고, 같은 형식이면 그대로 둔다', () {
    final jpg = _jpg(10, 10);
    final png = convertImage(jpg, ImageFormat.png);
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(identical(convertImage(jpg, ImageFormat.jpg), jpg), isTrue);
    expect(convertImage(png, ImageFormat.jpg).sublist(0, 2), [0xFF, 0xD8]);
  });

  test('기본 PDF 파일 이름', () {
    expect(defaultPdfName(DateTime(2026, 11, 1, 9, 5)), '스캔_20261101_0905.pdf');
  });
}
