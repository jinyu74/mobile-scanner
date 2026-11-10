import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_scanner/main.dart';

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
}
