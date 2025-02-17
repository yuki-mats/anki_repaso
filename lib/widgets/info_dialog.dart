import 'package:flutter/material.dart';

class InfoDialog extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback? onClose;
  final TextStyle? titleTextStyle;
  final TextStyle? contentTextStyle;
  final TextStyle? buttonTextStyle;
  final ShapeBorder? dialogShape;
  final Color? backgroundColor;

  const InfoDialog({
    Key? key,
    required this.title,
    required this.content,
    this.buttonText = '閉じる',
    this.onClose,
    this.titleTextStyle,
    this.contentTextStyle,
    this.buttonTextStyle,
    this.dialogShape,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: dialogShape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: backgroundColor ?? Colors.white,
      title: Text(title, style: titleTextStyle ?? const TextStyle(color: Colors.black, fontSize: 16)),
      content: Padding(
        padding: const EdgeInsets.only(left: 1.0),
        child: Text(content, style: contentTextStyle ?? const TextStyle(color: Colors.black)),
      ),
      actions: [
        TextButton(
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          child: Text(
            buttonText,
            style: buttonTextStyle ?? const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
