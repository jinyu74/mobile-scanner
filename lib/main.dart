import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

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
  const ScannerApp({super.key, this.scan = scanWithOsScanner});

  final DocumentScanFn scan;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A4 스캐너',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: HomeScreen(scan: scan),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.scan});

  final DocumentScanFn scan;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _pages = [];
  bool _scanning = false;

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
