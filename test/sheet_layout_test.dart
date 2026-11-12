import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/main.dart';
import 'package:mobile_scanner/ocr_service.dart';
import 'package:mobile_scanner/save_service.dart';

class _Saver implements SaveService {
  final calls = <String>[];

  @override
  Future<int> saveToGallery(List<String> paths, ImageFormat format) async =>
      paths.length;

  @override
  Future<bool> savePdf(List<String> paths, String fileName) async => true;

  @override
  Future<bool> saveText(String text, String fileName) async => true;

  @override
  Future<void> sharePdf(List<String> paths, String fileName, Rect? o) async =>
      calls.add('sharePdf');

  @override
  Future<void> shareImages(List<String> paths, Rect? o) async =>
      calls.add('shareImages');

  @override
  Future<void> shareText(String text, Rect? o) async =>
      calls.add('shareText:$text');
}

class _Ocr implements OcrService {
  @override
  Future<String> recognize(String imagePath) async => '글';
}

/// 화면 크기와 글씨 배율을 바꾼 뒤 스캔하고 저장 / 공유 시트를 연다.
Future<_Saver> _openSheet(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final saver = _Saver();
  await tester.pumpWidget(
    ScannerApp(scan: () async => ['/tmp/a.jpg'], saver: saver, ocr: _Ocr()),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('저장 / 공유'));
  await tester.pumpAndSettle();
  return saver;
}

/// 열린 시트에서 [label] 항목까지 스크롤해 누른다. 넘침이 없어야 한다.
Future<void> _scrollAndTap(WidgetTester tester, String label) async {
  expect(tester.takeException(), isNull, reason: '레이아웃 넘침이 없어야 한다');
  final sheetScroll = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.text(label),
    80,
    scrollable: sheetScroll.first,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// 저장 / 공유 시트의 마지막 항목(공유)과
/// 공유 형식 시트의 마지막 항목(추출한 텍스트)까지 닿는지 확인한다.
Future<void> _expectAllSheetsReachable(
  WidgetTester tester,
  _Saver saver,
) async {
  expect(find.text('텍스트 추출'), findsOneWidget);
  await _scrollAndTap(tester, '공유');
  expect(find.text('무엇을 보낼까요?'), findsOneWidget);
  await _scrollAndTap(tester, '추출한 텍스트');
  expect(saver.calls, ['shareText:글']);
}

void main() {
  group('저장 / 공유 시트 레이아웃', () {
    testWidgets('작은 세로 화면(375x667)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(tester, size: const Size(375, 667));
      await _expectAllSheetsReachable(tester, saver);
    });

    testWidgets('가로 화면(844x390)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(tester, size: const Size(844, 390));
      await _expectAllSheetsReachable(tester, saver);
    });

    testWidgets('작은 화면 + 큰 글씨(2배)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(
        tester,
        size: const Size(375, 667),
        textScale: 2.0,
      );
      await _expectAllSheetsReachable(tester, saver);
    });
  });
}
