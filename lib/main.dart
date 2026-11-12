import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

import 'action_sheet.dart';
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

  /// 선택 모드일 때 선택된 페이지 인덱스. null이면 선택 모드가 아니다.
  Set<int>? _selected;

  bool get _selecting => _selected != null;

  void _enterSelection() => setState(() => _selected = <int>{});

  void _exitSelection() => setState(() => _selected = null);

  void _toggle(int i) => setState(() {
    final sel = _selected!;
    if (!sel.remove(i)) sel.add(i);
  });

  void _toggleAll() => setState(() {
    final sel = _selected!;
    if (sel.length == _pages.length) {
      sel.clear();
    } else {
      sel.addAll(List.generate(_pages.length, (i) => i));
    }
  });

  Future<void> _confirmDelete() async {
    final count = _selected!.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('페이지 삭제'),
        content: Text('선택한 $count쪽을 삭제할까요? 삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      final sel = _selected!;
      final kept = [
        for (var i = 0; i < _pages.length; i++)
          if (!sel.contains(i)) _pages[i],
      ];
      _pages
        ..clear()
        ..addAll(kept);
      _selected = null;
    });
    _toast('$count쪽을 삭제했습니다.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSaveSheet() async {
    final action = await showActionSheet<SaveAction>(
      context,
      (_) => const SaveSheet(),
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

  static const _spinner = SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  List<Widget> _mainActions() {
    final scan = _pages.isEmpty
        ? FilledButton.icon(
            onPressed: _scanning ? null : _startScan,
            icon: _scanning
                ? _spinner
                : const Icon(Icons.document_scanner_outlined),
            label: const Text('스캔하기'),
          )
        : FilledButton.tonalIcon(
            onPressed: _scanning || _saving ? null : _startScan,
            icon: _scanning
                ? _spinner
                : const Icon(Icons.document_scanner_outlined),
            label: const Text('스캔하기'),
          );
    if (_pages.isEmpty) return [Expanded(child: scan)];
    return [
      Expanded(flex: 2, child: scan),
      Expanded(
        flex: 3,
        child: FilledButton.icon(
          onPressed: _saving || _scanning ? null : _openSaveSheet,
          icon: _saving ? _spinner : const Icon(Icons.save_alt),
          label: Text('저장 / 공유 (${_pages.length}쪽)'),
        ),
      ),
    ];
  }

  List<Widget> _selectionActions() {
    final scheme = Theme.of(context).colorScheme;
    final count = _selected!.length;
    return [
      Expanded(
        flex: 2,
        child: OutlinedButton.icon(
          onPressed: _toggleAll,
          icon: Icon(
            count == _pages.length ? Icons.deselect : Icons.select_all,
          ),
          label: Text(count == _pages.length ? '선택 해제' : '모두 선택'),
        ),
      ),
      Expanded(
        flex: 3,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: count == 0 ? null : _confirmDelete,
          icon: const Icon(Icons.delete_outline),
          label: Text('삭제 ($count)'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: '선택 취소',
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('${_selected!.length}쪽 선택됨'),
            )
          : AppBar(
              title: const Text('A4 스캐너'),
              actions: [
                if (_pages.isNotEmpty)
                  IconButton(
                    tooltip: '페이지 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _saving ? null : _enterSelection,
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
              itemBuilder: (context, i) => _PageTile(
                index: i,
                path: _pages[i],
                selecting: _selecting,
                selected: _selected?.contains(i) ?? false,
                onTap: _selecting ? () => _toggle(i) : null,
              ),
            ),
      bottomNavigationBar: _BottomBar(
        children: _selecting ? _selectionActions() : _mainActions(),
      ),
    );
  }
}

/// 화면 아래 고정 버튼 줄. 모든 버튼을 같은 높이(56)와 간격으로 맞춘다.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Theme(
            data: theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
              outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
            ),
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  children[i],
                ],
              ],
            ),
          ),
        ),
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
    return ActionSheetBody(
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
  const _PageTile({
    required this.index,
    required this.path,
    this.selecting = false,
    this.selected = false,
    this.onTap,
  });

  final int index;
  final String path;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          if (selecting) ...[
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  border: Border.all(color: scheme.primary, width: 3),
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onTap?.call(),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? scheme.primary
                      : Colors.white70,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
