import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/ocr_service.dart';

class _Ocr implements OcrService {
  _Ocr(this.texts);
  final Map<String, String> texts;
  final calls = <String>[];

  @override
  Future<String> recognize(String imagePath) async {
    calls.add(imagePath);
    return texts[imagePath] ?? '';
  }
}

void main() {
  test('한 쪽이면 머리말 없이 글만 돌려준다', () async {
    final text = await extractText(['a'], _Ocr({'a': '  안녕하세요\n반갑습니다  '}));
    expect(text, '안녕하세요\n반갑습니다');
  });

  test('여러 쪽을 순서대로 읽고 쪽 머리말을 붙인다', () async {
    final ocr = _Ocr({'a': '하나', 'b': '둘', 'c': '셋'});
    final progress = <int>[];
    final text = await extractText(
      ['a', 'b', 'c'],
      ocr,
      onProgress: (done, total) {
        expect(total, 3);
        progress.add(done);
      },
    );
    expect(ocr.calls, ['a', 'b', 'c']);
    expect(progress, [1, 2, 3]);
    expect(text, '[1쪽]\n하나\n\n[2쪽]\n둘\n\n[3쪽]\n셋');
  });

  test('글자가 없는 쪽은 건너뛰고, 모두 없으면 빈 문자열', () async {
    expect(await extractText(['a', 'b'], _Ocr({'b': 'B'})), '[2쪽]\nB');
    expect(await extractText(['a', 'b'], _Ocr({})), '');
  });
}
