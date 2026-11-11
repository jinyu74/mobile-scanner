import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

import 'save_service.dart';

/// 스캔을 실행하고 페이지 이미지 경로 목록을 돌려준다. 취소하면 null.
typedef DocumentScanFn = Future<List<String>?> Function();

/// OS 기본 스캐너(iOS VisionKit / Android ML Kit)를 띄운다.
Future<List<String>?> scanWithOsScanner() async {
  final result = await CunningDocumentScanner.scanDocuments();
  return result?.images;
}

void main() {
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({
    super.key,
    this.scan = scanWithOsScanner,
    this.saver = const DeviceSaveService(),
  });

  final DocumentScanFn scan;
  final SaveService saver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A4 스캐너',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: HomeScreen(scan: scan, saver: saver),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.scan, required this.saver});

  final DocumentScanFn scan;
  final SaveService saver;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _pages = [];
  bool _scanning = false;
  bool _saving = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSaveSheet() async {
    final action = await showModalBottomSheet<SaveAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SaveSheet(),
    );
    if (action == null || !mounted) return;
    await _runSave(action);
  }

  Future<void> _runSave(SaveAction action) async {
    final pages = List<String>.of(_pages);
    setState(() => _saving = true);
    try {
      switch (action) {
        case SaveAction.galleryJpg:
        case SaveAction.galleryPng:
          final format = action == SaveAction.galleryPng
              ? ImageFormat.png
              : ImageFormat.jpg;
          final n = await widget.saver.saveToGallery(pages, format);
          if (mounted) {
            _toast('사진첩에 $n장을 ${format.name.toUpperCase()}로 저장했습니다.');
          }
        case SaveAction.pdf:
          final saved = await widget.saver.savePdf(
            pages,
            defaultPdfName(DateTime.now()),
          );
          if (mounted && saved) _toast('PDF(${pages.length}쪽)를 저장했습니다.');
        case SaveAction.share:
          await widget.saver.share(pages);
      }
    } catch (e) {
      if (mounted) _toast('저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);
    try {
      final images = await widget.scan();
      if (!mounted || images == null) return;
      setState(() => _pages.addAll(images));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('스캔에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A4 스캐너'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: '모두 지우기',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(_pages.clear),
            ),
        ],
      ),
      body: _pages.isEmpty
          ? const _EmptyView()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1 / 1.414, // A4 비율
              ),
              itemCount: _pages.length,
              itemBuilder: (context, i) => _PageTile(index: i, path: _pages[i]),
            ),
      bottomNavigationBar: _pages.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _openSaveSheet,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text('저장 / 공유 (${_pages.length}쪽)'),
                    ),
                  ),
                  // FAB 자리를 비워 둔다.
                  const SizedBox(width: 140),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _startScan,
        icon: _scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: const Text('스캔하기'),
      ),
    );
  }
}

enum SaveAction { galleryJpg, galleryPng, pdf, share }

class SaveSheet extends StatelessWidget {
  const SaveSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void pick(SaveAction a) => Navigator.of(context).pop(a);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('사진첩에 저장 (JPG)'),
            subtitle: const Text('용량이 작아 일반적인 용도에 알맞습니다'),
            onTap: () => pick(SaveAction.galleryJpg),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('사진첩에 저장 (PNG)'),
            subtitle: const Text('화질 손실 없이 저장합니다'),
            onTap: () => pick(SaveAction.galleryPng),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF로 저장'),
            subtitle: const Text('모든 페이지를 A4 PDF 한 파일로 저장합니다'),
            onTap: () => pick(SaveAction.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('공유'),
            onTap: () => pick(SaveAction.share),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 72, color: color),
          const SizedBox(height: 12),
          Text(
            '아직 스캔한 문서가 없습니다.\n아래 "스캔하기" 버튼을 눌러 시작하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({required this.index, required this.path});

  final int index;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.broken_image_outlined)),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${index + 1}쪽',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
