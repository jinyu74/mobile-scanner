import 'package:flutter/services.dart';
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

  group('PlatformOcrService', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.jinyu74.scanner/ocr');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('네이티브가 돌려준 글을 그대로 돌려준다', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recognize');
        expect(call.arguments, {'path': '/tmp/a.jpg'});
        return '안녕하세요';
      });
      expect(await const PlatformOcrService().recognize('/tmp/a.jpg'), '안녕하세요');
    });

    test('한국어 미지원 기기면 안내 문구가 담긴 OcrException을 던진다', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'korean_unsupported');
      });
      await expectLater(
        const PlatformOcrService().recognize('/tmp/a.jpg'),
        throwsA(
          isA<OcrException>().having(
            (e) => e.message,
            'message',
            '이 기기에서는 한국어 텍스트 인식을 지원하지 않습니다.',
          ),
        ),
      );
    });

    test('그 밖의 네이티브 오류는 그대로 전달한다', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ocr_failed', message: 'x');
      });
      await expectLater(
        const PlatformOcrService().recognize('/tmp/a.jpg'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
