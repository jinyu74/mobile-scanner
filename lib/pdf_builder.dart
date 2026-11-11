import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 스캔 이미지들을 A4(595x842pt) 페이지에 한 장씩, 비율을 유지하며 맞춰 넣은 PDF.
Future<Uint8List> buildA4Pdf(List<Uint8List> pageImages) async {
  final doc = pw.Document(title: 'A4 스캔', creator: 'A4 스캐너');
  for (final bytes in pageImages) {
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return doc.save();
}
