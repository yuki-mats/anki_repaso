import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

class NameInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  /// ラベルテキスト（入力中は上部に表示される）
  final String labelText;
  /// ヒントテキスト（未入力時に表示）
  final String hintText;
  const NameInput({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.labelText = '名前',
    this.hintText = '例）サンプル名',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // フォーカス状態とテキストの有無で表示内容を制御
    final bool hasFocus = focusNode.hasFocus;
    final bool hasText = controller.text.isNotEmpty;

    return Container(
      alignment: Alignment.center,
      height: 64, // レイアウトに合わせた固定高さ
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.transparent, // フォーカス/非フォーカスともに無色
          width: 2.0,
        ),
      ),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 1,
        style: const TextStyle(height: 1.5),
        cursorColor: AppColors.blue600,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          // 入力中またはテキストがある場合にラベル表示
          labelText: (hasFocus || hasText) ? labelText : null,
          // フォーカス中かつ未入力の場合はヒントテキストを表示
          hintText: (!hasFocus && !hasText)
              ? labelText
              : (hasFocus && !hasText)
              ? hintText
              : null,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          floatingLabelStyle: const TextStyle(color: AppColors.blue600),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
