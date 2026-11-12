import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'pdf_builder.dart';

enum ImageFormat { jpg, png }

/// 저장/공유 동작. 테스트에서는 가짜 구현으로 바꿔 끼운다.
abstract class SaveService {
  /// 각 페이지를 사진첩에 저장한다. 저장한 장 수를 돌려준다.
  Future<int> saveToGallery(List<String> paths, ImageFormat format);

  /// 모든 페이지를 A4 PDF 하나로 묶어 저장한다. 사용자가 취소하면 false.
  Future<bool> savePdf(List<String> paths, String fileName);

  /// 추출한 글을 .txt 파일로 저장한다. 사용자가 취소하면 false.
  Future<bool> saveText(String text, String fileName);

  /// 모든 페이지를 A4 PDF 하나로 묶어 공유 시트로 보낸다.
  /// [origin]은 iPad에서 공유 창이 가리킬 위치다.
  Future<void> sharePdf(List<String> paths, String fileName, Rect? origin);

  /// 페이지 이미지를 JPG로 공유한다.
  Future<void> shareImages(List<String> paths, Rect? origin);

  /// 글을 공유한다.
  Future<void> shareText(String text, Rect? origin);
}

class DeviceSaveService implements SaveService {
  const DeviceSaveService();

  static const _album = 'A4 스캐너';

  @override
  Future<int> saveToGallery(List<String> paths, ImageFormat format) async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) {
        throw const SaveException('사진첩 접근 권한이 없습니다. 설정에서 허용해 주세요.');
      }
    }
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var i = 0;
    for (final path in paths) {
      i++;
      final ext = format == ImageFormat.png ? 'png' : 'jpg';
      final out = File('${tmp.path}/scan_${stamp}_$i.$ext');
      final bytes = await Isolate.run(
        () => convertImage(File(path).readAsBytesSync(), format),
      );
      await out.writeAsBytes(bytes);
      await Gal.putImage(out.path, album: _album);
      await out.delete();
    }
    return paths.length;
  }

  @override
  Future<bool> savePdf(List<String> paths, String fileName) async {
    final pages = [for (final p in paths) await File(p).readAsBytes()];
    final pdf = await buildA4Pdf(pages);
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: pdf,
      mimeType: 'application/pdf',
      dialogTitle: 'PDF 저장 위치 선택',
    );
    return uri != null;
  }

  @override
  Future<bool> saveText(String text, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'text/plain',
      dialogTitle: '텍스트 저장 위치 선택',
    );
    return uri != null;
  }

  @override
  Future<void> sharePdf(
    List<String> paths,
    String fileName,
    Rect? origin,
  ) async {
    final pages = [for (final p in paths) await File(p).readAsBytes()];
    final pdf = await buildA4Pdf(pages);
    final dir = await _shareDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdf);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Future<void> shareImages(List<String> paths, Rect? origin) async {
    final dir = await _shareDir();
    final files = <XFile>[];
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final bytes = await Isolate.run(
        () => convertImage(File(path).readAsBytesSync(), ImageFormat.jpg),
      );
      final out = File('${dir.path}/스캔_${i + 1}쪽.jpg');
      await out.writeAsBytes(bytes);
      files.add(XFile(out.path, mimeType: 'image/jpeg'));
    }
    await SharePlus.instance.share(
      ShareParams(files: files, sharePositionOrigin: origin),
    );
  }

  @override
  Future<void> shareText(String text, Rect? origin) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  /// 공유용 임시 폴더. 지난번 공유 파일은 지운다.
  Future<Directory> _shareDir() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    if (await dir.exists()) await dir.delete(recursive: true);
    return dir.create(recursive: true);
  }
}

class SaveException implements Exception {
  const SaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 이미지를 원하는 형식으로 다시 인코딩한다. 이미 같은 형식이면 그대로 둔다.
Uint8List convertImage(Uint8List bytes, ImageFormat format) {
  final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
  final isJpg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  if ((format == ImageFormat.png && isPng) ||
      (format == ImageFormat.jpg && isJpg)) {
    return bytes;
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const SaveException('이미지를 읽을 수 없습니다.');
  }
  return format == ImageFormat.png
      ? img.encodePng(decoded)
      : img.encodeJpg(decoded, quality: 92);
}

/// 예: 스캔_20261111_1630.pdf
String defaultPdfName(DateTime now) => '${_baseName(now)}.pdf';

/// 예: 스캔_20261111_1630.txt
String defaultTextName(DateTime now) => '${_baseName(now)}.txt';

String _baseName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '스캔_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}';
}
