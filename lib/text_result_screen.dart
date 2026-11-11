import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bottom_action_bar.dart';
import 'save_service.dart';

/// 추출한 글을 보여 주고 고칠 수 있는 화면. 복사·공유·.txt 저장을 할 수 있다.
class TextResultScreen extends StatefulWidget {
  const TextResultScreen({super.key, required this.text, required this.saver});

  final String text;
  final SaveService saver;

  @override
  State<TextResultScreen> createState() => _TextResultScreenState();
}

class _TextResultScreenState extends State<TextResultScreen> {
  late final _controller = TextEditingController(text: widget.text);
  final _shareKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (mounted) _toast('텍스트를 복사했습니다.');
  }

  Future<void> _share() async {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await widget.saver.shareText(_controller.text, origin);
    } on Exception catch (e) {
      if (mounted) _toast('공유에 실패했습니다: $e');
    }
  }

  Future<void> _saveTxt() async {
    try {
      final saved = await widget.saver.saveText(
        _controller.text,
        defaultTextName(DateTime.now()),
      );
      if (mounted && saved) _toast('텍스트 파일(.txt)을 저장했습니다.');
    } on Exception catch (e) {
      if (mounted) _toast('저장에 실패했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추출한 텍스트')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            helperText: '필요하면 글을 고친 뒤 복사·공유·저장하세요.',
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: const Text('복사'),
            ),
          ),
          Expanded(
            child: OutlinedButton.icon(
              key: _shareKey,
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              label: const Text('공유'),
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saveTxt,
              icon: const Icon(Icons.save_alt),
              label: const Text('.txt로 저장'),
            ),
          ),
        ],
      ),
    );
  }
}
