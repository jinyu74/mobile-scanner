import 'package:flutter/material.dart';

/// 화면 아래 고정 버튼 줄. 모든 버튼을 같은 높이(56)와 간격으로 맞춘다.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

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
