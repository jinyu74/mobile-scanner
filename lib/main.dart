import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';

import 'action_sheet.dart';
import 'bottom_action_bar.dart';
import 'ocr_service.dart';
import 'save_service.dart';
import 'text_result_screen.dart';

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
    this.ocr = const PlatformOcrService(),
  });

  final DocumentScanFn scan;
  final SaveService saver;
  final OcrService ocr;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A4 스캐너',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: HomeScreen(scan: scan, saver: saver, ocr: ocr),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.scan,
    required this.saver,
    required this.ocr,
  });

  final DocumentScanFn scan;
  final SaveService saver;
  final OcrService ocr;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _pages = [];
  bool _scanning = false;
  bool _saving = false;

  /// 저장 / 공유 버튼. iPad에서 공유 창이 이 버튼을 가리키게 한다.
  final _actionKey = GlobalKey();

  Rect? _shareOrigin() {
    final box = _actionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

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
    ShareFormat? format;
    if (action == SaveAction.share) {
      format = await showActionSheet<ShareFormat>(
        context,
        (_) => const ShareFormatSheet(),
      );
      if (format == null || !mounted) return;
    }
    await _runSave(action, format);
  }

  Future<void> _runSave(SaveAction action, [ShareFormat? format]) async {
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
        case SaveAction.extractText:
          final text = await _extractText(pages);
          if (text == null || !mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TextResultScreen(text: text, saver: widget.saver),
            ),
          );
        case SaveAction.share:
          final origin = _shareOrigin();
          switch (format!) {
            case ShareFormat.pdf:
              await widget.saver.sharePdf(
                pages,
                defaultPdfName(DateTime.now()),
                origin,
              );
            case ShareFormat.images:
              await widget.saver.shareImages(pages, origin);
            case ShareFormat.text:
              final text = await _extractText(pages);
              if (text == null) return;
              await widget.saver.shareText(text, origin);
          }
      }
    } catch (e) {
      if (mounted) _toast('저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 모든 페이지에서 글자를 읽는다. 진행 상황 창을 띄우고,
  /// 글자가 없으면 안내를 띄운 뒤 null을 돌려준다.
  Future<String?> _extractText(List<String> pages) async {
    final progress = ValueNotifier<int>(0);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('텍스트 추출 중'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: pages.isEmpty ? null : done / pages.length,
                ),
                const SizedBox(height: 12),
                Text('$done / ${pages.length}쪽'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final text = await extractText(
        pages,
        widget.ocr,
        onProgress: (done, _) => progress.value = done,
      );
      if (text.isEmpty) {
        if (mounted) _toast('텍스트를 찾지 못했습니다.');
        return null;
      }
      return text;
    } on Exception catch (e) {
      if (mounted) _toast('텍스트 추출에 실패했습니다: $e');
      return null;
    } finally {
      navigator.pop();
      progress.dispose();
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
          key: _actionKey,
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
      bottomNavigationBar: BottomActionBar(
        children: _selecting ? _selectionActions() : _mainActions(),
      ),
    );
  }
}

enum SaveAction { galleryJpg, galleryPng, pdf, extractText, share }

enum ShareFormat { pdf, images, text }

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
          leading: const Icon(Icons.text_snippet_outlined),
          title: const Text('텍스트 추출'),
          subtitle: const Text('문서의 글자를 읽어 복사·공유·저장합니다'),
          onTap: () => pick(SaveAction.extractText),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('공유'),
          subtitle: const Text('메일, 메시지, 카카오톡, 텔레그램 등으로 보냅니다'),
          onTap: () => pick(SaveAction.share),
        ),
      ],
    );
  }
}

/// 무엇을 보낼지 고르는 시트. 고른 뒤 시스템 공유 창이 열리고,
/// 거기서 메일·메시지·카카오톡·텔레그램 등 설치된 앱을 고른다.
class ShareFormatSheet extends StatelessWidget {
  const ShareFormatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void pick(ShareFormat f) => Navigator.of(context).pop(f);
    return ActionSheetBody(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '무엇을 보낼까요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: const Text('PDF (모든 페이지)'),
          onTap: () => pick(ShareFormat.pdf),
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('이미지 (JPG)'),
          onTap: () => pick(ShareFormat.images),
        ),
        ListTile(
          leading: const Icon(Icons.text_snippet_outlined),
          title: const Text('추출한 텍스트'),
          onTap: () => pick(ShareFormat.text),
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
