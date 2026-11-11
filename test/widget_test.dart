import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_scanner/main.dart';
import 'package:mobile_scanner/save_service.dart';

class FakeSaver implements SaveService {
  final calls = <String>[];
  bool pdfSaved = true;
  Object? error;

  @override
  Future<int> saveToGallery(List<String> paths, ImageFormat format) async {
    if (error != null) throw error!;
    calls.add('gallery:${format.name}:${paths.length}');
    return paths.length;
  }

  @override
  Future<bool> savePdf(List<String> paths, String fileName) async {
    calls.add('pdf:${paths.length}');
    return pdfSaved;
  }

  @override
  Future<void> share(List<String> paths) async =>
      calls.add('share:${paths.length}');
}

Future<FakeSaver> _scanTwoPages(WidgetTester tester) async {
  final saver = FakeSaver();
  await tester.pumpWidget(
    ScannerApp(scan: () async => ['/tmp/a.jpg', '/tmp/b.jpg'], saver: saver),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
  return saver;
}

Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.textContaining('저장 / 공유'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음에는 빈 화면과 스캔하기 버튼이 보인다', (tester) async {
    await tester.pumpWidget(ScannerApp(scan: () async => null));

    expect(find.text('A4 스캐너'), findsOneWidget);
    expect(find.text('스캔하기'), findsOneWidget);
    expect(find.textContaining('아직 스캔한 문서가 없습니다'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('스캔 결과가 그리드에 페이지로 표시된다', (tester) async {
    await tester.pumpWidget(
      ScannerApp(scan: () async => ['/tmp/a.jpg', '/tmp/b.jpg']),
    );

    await tester.tap(find.text('스캔하기'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('1쪽'), findsOneWidget);
    expect(find.text('2쪽'), findsOneWidget);
  });

  testWidgets('스캔을 취소하면 아무것도 추가되지 않는다', (tester) async {
    await tester.pumpWidget(ScannerApp(scan: () async => null));

    await tester.tap(find.text('스캔하기'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('스캔 전에는 저장 버튼이 없다', (tester) async {
    await tester.pumpWidget(ScannerApp(scan: () async => null));
    expect(find.textContaining('저장 / 공유'), findsNothing);
  });

  testWidgets('저장 시트에 네 가지 옵션이 있다', (tester) async {
    await _scanTwoPages(tester);
    expect(find.text('저장 / 공유 (2쪽)'), findsOneWidget);

    await tester.tap(find.textContaining('저장 / 공유'));
    await tester.pumpAndSettle();

    expect(find.text('사진첩에 저장 (JPG)'), findsOneWidget);
    expect(find.text('사진첩에 저장 (PNG)'), findsOneWidget);
    expect(find.text('PDF로 저장'), findsOneWidget);
    expect(find.text('공유'), findsOneWidget);
  });

  testWidgets('사진첩에 PNG로 저장하면 안내가 뜬다', (tester) async {
    final saver = await _scanTwoPages(tester);
    await _choose(tester, '사진첩에 저장 (PNG)');

    expect(saver.calls, ['gallery:png:2']);
    expect(find.text('사진첩에 2장을 PNG로 저장했습니다.'), findsOneWidget);
  });

  testWidgets('PDF로 저장하면 안내가 뜨고, 취소하면 뜨지 않는다', (tester) async {
    final saver = await _scanTwoPages(tester);
    await _choose(tester, 'PDF로 저장');
    expect(saver.calls, ['pdf:2']);
    expect(find.text('PDF(2쪽)를 저장했습니다.'), findsOneWidget);

    saver.pdfSaved = false;
    ScaffoldMessenger.of(tester.element(find.byType(GridView)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await _choose(tester, 'PDF로 저장');
    expect(find.text('PDF(2쪽)를 저장했습니다.'), findsNothing);
  });

  testWidgets('공유를 고르면 공유 시트를 연다', (tester) async {
    final saver = await _scanTwoPages(tester);
    await _choose(tester, '공유');
    expect(saver.calls, ['share:2']);
  });

  testWidgets('저장에 실패하면 오류 안내가 뜬다', (tester) async {
    final saver = await _scanTwoPages(tester);
    saver.error = const SaveException('사진첩 접근 권한이 없습니다.');
    await _choose(tester, '사진첩에 저장 (JPG)');
    expect(find.text('저장에 실패했습니다: 사진첩 접근 권한이 없습니다.'), findsOneWidget);
  });
}
