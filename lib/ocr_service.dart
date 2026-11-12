import 'package:flutter/services.dart';

/// 사용자에게 그대로 보여 줄 수 있는 텍스트 인식 오류.
class OcrException implements Exception {
  const OcrException(this.message);
  final String message;

  static const koreanUnsupported = OcrException(
    '이 기기에서는 한국어 텍스트 인식을 지원하지 않습니다.',
  );

  @override
  String toString() => message;
}

/// 이미지 한 장에서 글자를 읽는다.
abstract class OcrService {
  Future<String> recognize(String imagePath);
}

/// iOS는 Apple Vision, Android는 ML Kit 한국어 인식기를 쓴다(모두 기기 안에서 처리).
class PlatformOcrService implements OcrService {
  const PlatformOcrService();

  static const _channel = MethodChannel('com.jinyu74.scanner/ocr');

  @override
  Future<String> recognize(String imagePath) async {
    try {
      final text = await _channel.invokeMethod<String>('recognize', {
        'path': imagePath,
      });
      return text ?? '';
    } on PlatformException catch (e) {
      if (e.code == 'korean_unsupported') throw OcrException.koreanUnsupported;
      rethrow;
    }
  }
}

/// 모든 페이지를 순서대로 읽어 하나의 글로 합친다. 글자가 하나도 없으면 빈 문자열.
///
/// 여러 쪽이면 각 쪽 앞에 "[N쪽]" 머리말을 붙인다. 글자가 없는 쪽은 건너뛴다.
Future<String> extractText(
  List<String> pages,
  OcrService ocr, {
  void Function(int done, int total)? onProgress,
}) async {
  final parts = <String>[];
  for (var i = 0; i < pages.length; i++) {
    final text = (await ocr.recognize(pages[i])).trim();
    onProgress?.call(i + 1, pages.length);
    if (text.isEmpty) continue;
    parts.add(pages.length == 1 ? text : '[${i + 1}쪽]\n$text');
  }
  return parts.join('\n\n');
}
