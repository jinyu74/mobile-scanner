import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_scanner/main.dart';
import 'package:mobile_scanner/ocr_service.dart';
import 'package:mobile_scanner/save_service.dart';
import 'package:mobile_scanner/text_result_screen.dart';

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
  Future<bool> saveText(String text, String fileName) async {
    calls.add('saveText:$text');
    return true;
  }

  final origins = <Rect?>[];

  @override
  Future<void> sharePdf(
    List<String> paths,
    String fileName,
    Rect? origin,
  ) async {
    origins.add(origin);
    calls.add('sharePdf:${paths.length}');
  }

  @override
  Future<void> shareImages(List<String> paths, Rect? origin) async {
    origins.add(origin);
    calls.add('shareImages:${paths.length}');
  }

  @override
  Future<void> shareText(String text, Rect? origin) async {
    origins.add(origin);
    calls.add('shareText:$text');
  }
}

/// 경로마다 정해 둔 글을 돌려주는 가짜 OCR.
class FakeOcr implements OcrService {
  FakeOcr(this.texts);
  final Map<String, String> texts;

  @override
  Future<String> recognize(String imagePath) async => texts[imagePath] ?? '';
}

Future<FakeSaver> _scanWithOcr(WidgetTester tester, FakeOcr ocr) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  final saver = FakeSaver();
  await tester.pumpWidget(
    ScannerApp(
      scan: () async => ['/tmp/a.jpg', '/tmp/b.jpg'],
      saver: saver,
      ocr: ocr,
    ),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
  return saver;
}

Future<FakeSaver> _scanTwoPages(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  final saver = FakeSaver();
  await tester.pumpWidget(
    ScannerApp(scan: () async => ['/tmp/a.jpg', '/tmp/b.jpg'], saver: saver),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
  return saver;
}

Future<void> _scanPages(WidgetTester tester, int n) async {
  // 모든 페이지가 한 화면에 보이도록 세로로 긴 화면을 쓴다.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScannerApp(
      scan: () async => [for (var i = 0; i < n; i++) '/tmp/p$i.jpg'],
      saver: FakeSaver(),
    ),
  );
  await tester.tap(find.text('스캔하기'));
  await tester.pumpAndSettle();
}

Future<void> _tapPage(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
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
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('스캔하기와 저장 버튼이 같은 줄에 같은 높이로 놓인다', (tester) async {
    await _scanTwoPages(tester);
    final scan = tester.getRect(
      find.ancestor(
        of: find.text('스캔하기'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    final save = tester.getRect(
      find.ancestor(
        of: find.text('저장 / 공유 (2쪽)'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(scan.height, 56);
    expect(save.height, 56);
    expect(scan.bottom, save.bottom);
    expect(scan.right, lessThan(save.left));
  });

  testWidgets('저장 시트에 다섯 가지 옵션이 있다', (tester) async {
    await _scanTwoPages(tester);
    expect(find.text('저장 / 공유 (2쪽)'), findsOneWidget);

    await tester.tap(find.textContaining('저장 / 공유'));
    await tester.pumpAndSettle();

    expect(find.text('사진첩에 저장 (JPG)'), findsOneWidget);
    expect(find.text('사진첩에 저장 (PNG)'), findsOneWidget);
    expect(find.text('PDF로 저장'), findsOneWidget);
    expect(find.text('텍스트 추출'), findsOneWidget);
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

  group('공유 형식 선택', () {
    testWidgets('공유를 고르면 보낼 형식을 묻는다', (tester) async {
      await _scanTwoPages(tester);
      await _choose(tester, '공유');
      expect(find.text('무엇을 보낼까요?'), findsOneWidget);
      expect(find.text('PDF (모든 페이지)'), findsOneWidget);
      expect(find.text('이미지 (JPG)'), findsOneWidget);
      expect(find.text('추출한 텍스트'), findsOneWidget);
    });

    testWidgets('PDF를 고르면 PDF를 공유하고 iPad용 위치를 넘긴다', (tester) async {
      final saver = await _scanTwoPages(tester);
      await _choose(tester, '공유');
      await tester.tap(find.text('PDF (모든 페이지)'));
      await tester.pumpAndSettle();
      expect(saver.calls, ['sharePdf:2']);
      expect(saver.origins.single, isNotNull);
      expect(saver.origins.single!.isEmpty, isFalse);
    });

    testWidgets('이미지를 고르면 JPG 이미지를 공유한다', (tester) async {
      final saver = await _scanTwoPages(tester);
      await _choose(tester, '공유');
      await tester.tap(find.text('이미지 (JPG)'));
      await tester.pumpAndSettle();
      expect(saver.calls, ['shareImages:2']);
    });

    testWidgets('텍스트를 고르면 글자를 읽어 공유한다', (tester) async {
      final saver = await _scanWithOcr(
        tester,
        FakeOcr({'/tmp/a.jpg': '안녕하세요', '/tmp/b.jpg': 'Hello'}),
      );
      await _choose(tester, '공유');
      await tester.tap(find.text('추출한 텍스트'));
      await tester.pumpAndSettle();
      expect(saver.calls, ['shareText:[1쪽]\n안녕하세요\n\n[2쪽]\nHello']);
    });

    testWidgets('글자가 없으면 공유하지 않고 안내한다', (tester) async {
      final saver = await _scanWithOcr(tester, FakeOcr({}));
      await _choose(tester, '공유');
      await tester.tap(find.text('추출한 텍스트'));
      await tester.pumpAndSettle();
      expect(saver.calls, isEmpty);
      expect(find.text('텍스트를 찾지 못했습니다.'), findsOneWidget);
    });
  });

  group('텍스트 추출', () {
    testWidgets('추출한 글을 결과 화면에 보여 준다', (tester) async {
      await _scanWithOcr(
        tester,
        FakeOcr({'/tmp/a.jpg': '첫 쪽 내용', '/tmp/b.jpg': '둘째 쪽 내용'}),
      );
      await _choose(tester, '텍스트 추출');

      expect(find.byType(TextResultScreen), findsOneWidget);
      expect(find.text('추출한 텍스트'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '[1쪽]\n첫 쪽 내용\n\n[2쪽]\n둘째 쪽 내용');
      expect(find.text('복사'), findsOneWidget);
      expect(find.text('공유'), findsOneWidget);
      expect(find.text('.txt로 저장'), findsOneWidget);
    });

    testWidgets('글자가 없으면 결과 화면 대신 안내를 띄운다', (tester) async {
      await _scanWithOcr(tester, FakeOcr({'/tmp/a.jpg': '   '}));
      await _choose(tester, '텍스트 추출');
      expect(find.byType(TextResultScreen), findsNothing);
      expect(find.text('텍스트를 찾지 못했습니다.'), findsOneWidget);
    });

    testWidgets('결과 화면에서 고친 글을 복사·공유·저장한다', (tester) async {
      final saver = FakeSaver();
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TextResultScreen(text: '원문', saver: saver),
        ),
      );
      await tester.enterText(find.byType(TextField), '고친 글');

      await tester.tap(find.text('복사'));
      await tester.pumpAndSettle();
      expect(clip, '고친 글');
      expect(find.text('텍스트를 복사했습니다.'), findsOneWidget);

      await tester.tap(find.text('공유'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('.txt로 저장'));
      await tester.pumpAndSettle();
      expect(saver.calls, ['shareText:고친 글', 'saveText:고친 글']);
      expect(saver.origins.single, isNotNull);
      expect(find.text('텍스트 파일(.txt)을 저장했습니다.'), findsOneWidget);
    });
  });

  testWidgets('저장에 실패하면 오류 안내가 뜬다', (tester) async {
    final saver = await _scanTwoPages(tester);
    saver.error = const SaveException('사진첩 접근 권한이 없습니다.');
    await _choose(tester, '사진첩에 저장 (JPG)');
    expect(find.text('저장에 실패했습니다: 사진첩 접근 권한이 없습니다.'), findsOneWidget);
  });

  group('페이지 삭제', () {
    testWidgets('삭제 아이콘을 누르면 선택 모드가 되고 바로 지우지 않는다', (tester) async {
      await _scanPages(tester, 2);
      await tester.tap(find.byTooltip('페이지 삭제'));
      await tester.pumpAndSettle();

      expect(find.text('0쪽 선택됨'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('2쪽'), findsOneWidget);
      expect(find.text('스캔하기'), findsNothing);
      expect(find.textContaining('저장 / 공유'), findsNothing);
      final delete = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('삭제 (0)'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(delete.onPressed, isNull);
    });

    testWidgets('X를 누르면 선택 모드에서 나온다', (tester) async {
      await _scanPages(tester, 2);
      await tester.tap(find.byTooltip('페이지 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('선택 취소'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('2쪽'), findsOneWidget);
      expect(find.text('스캔하기'), findsOneWidget);
    });

    testWidgets('모두 선택과 선택 해제', (tester) async {
      await _scanPages(tester, 3);
      await tester.tap(find.byTooltip('페이지 삭제'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('모두 선택'));
      await tester.pump();
      expect(find.text('3쪽 선택됨'), findsOneWidget);
      expect(find.text('삭제 (3)'), findsOneWidget);

      await tester.tap(find.text('선택 해제'));
      await tester.pump();
      expect(find.text('0쪽 선택됨'), findsOneWidget);
    });

    testWidgets('확인 창에서 취소하면 페이지가 그대로다', (tester) async {
      await _scanPages(tester, 3);
      await tester.tap(find.byTooltip('페이지 삭제'));
      await tester.pumpAndSettle();
      await _tapPage(tester, '2쪽');
      await tester.tap(find.text('삭제 (1)'));
      await tester.pumpAndSettle();

      expect(find.text('선택한 1쪽을 삭제할까요? 삭제하면 되돌릴 수 없습니다.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('3쪽'), findsOneWidget);
      expect(find.text('1쪽 선택됨'), findsOneWidget);
    });

    testWidgets('확인하면 선택한 페이지만 지우고 번호를 다시 매긴다', (tester) async {
      await _scanPages(tester, 3);
      await tester.tap(find.byTooltip('페이지 삭제'));
      await tester.pumpAndSettle();
      await _tapPage(tester, '1쪽');
      await _tapPage(tester, '3쪽');
      expect(find.text('2쪽 선택됨'), findsOneWidget);

      await tester.tap(find.text('삭제 (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pumpAndSettle();

      final grid = find.byType(GridView);
      expect(
        find.descendant(of: grid, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(find.text('1쪽'), findsOneWidget);
      expect(find.text('2쪽'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('저장 / 공유 (1쪽)'), findsOneWidget);
      expect(find.text('2쪽을 삭제했습니다.'), findsOneWidget);
    });
  });
}
