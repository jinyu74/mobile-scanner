import 'package:flutter/material.dart';

/// 선택지 목록을 아래에서 올라오는 시트로 띄운다.
///
/// 작은 화면·가로 화면·큰 글씨에서도 모든 항목에 닿을 수 있도록
/// 화면 높이의 90%까지 쓰고, 넘치면 스크롤된다.
Future<T?> showActionSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: builder,
  );
}

/// [showActionSheet] 안에 넣는 스크롤되는 항목 목록.
class ActionSheetBody extends StatelessWidget {
  const ActionSheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
