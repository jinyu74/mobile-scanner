import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/main.dart';
import 'package:mobile_scanner/save_service.dart';

class _Saver implements SaveService {
  final calls = <String>[];

  @override
  Future<int> saveToGallery(List<String> paths, ImageFormat format) async =>
      paths.length;

  @override
  Future<bool> savePdf(List<String> paths, String fileName) async => true;

  @override
  Future<void> share(List<String> paths) async => calls.add('share');
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
    ScannerApp(scan: () async => ['/tmp/a.jpg', '/tmp/b.jpg'], saver: saver),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('저장 / 공유'));
  await tester.pumpAndSettle();
  return saver;
}

/// 시트의 마지막 항목(공유)까지 스크롤해서 누를 수 있는지 확인한다.
Future<void> _expectLastOptionReachable(
  WidgetTester tester,
  _Saver saver,
) async {
  expect(tester.takeException(), isNull, reason: '레이아웃 넘침이 없어야 한다');
  final sheetScroll = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    find.text('공유'),
    80,
    scrollable: sheetScroll.first,
  );
  await tester.tap(find.text('공유'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(saver.calls, ['share']);
}

void main() {
  group('저장 / 공유 시트 레이아웃', () {
    testWidgets('작은 세로 화면(375x667)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(tester, size: const Size(375, 667));
      await _expectLastOptionReachable(tester, saver);
    });

    testWidgets('가로 화면(844x390)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(tester, size: const Size(844, 390));
      await _expectLastOptionReachable(tester, saver);
    });

    testWidgets('작은 화면 + 큰 글씨(2배)에서 마지막 항목까지 닿는다', (tester) async {
      final saver = await _openSheet(
        tester,
        size: const Size(375, 667),
        textScale: 2.0,
      );
      await _expectLastOptionReachable(tester, saver);
    });
  });
}
