//Users/yuki/StudioProjects/repaso/lib/widgets/dialogs/delete_confirmation_dialog.dart
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

/// 結果オブジェクト
class DeleteDialogResult {
  const DeleteDialogResult({required this.confirmed, this.checked = false});

  final bool confirmed; // true = OK が押された
  final bool checked;   // チェックボックスの最終状態
}

/// 汎用削除確認ダイアログ
class DeleteConfirmationDialog extends StatefulWidget {
  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.bulletPoints,
    this.description,
    this.confirmText = '削除',
    this.cancelText = 'キャンセル',
    this.showCheckbox = false,
    this.initialChecked = false,
    this.checkboxLabel = '',
    this.confirmColor = Colors.redAccent,
  });

  /// ダイアログタイトル
  final String title;

  /// 箇条書き表示する項目
  final List<String> bulletPoints;

  /// 説明文（任意）
  final String? description;

  /// 確定ボタンテキスト
  final String confirmText;

  /// キャンセルボタンテキスト
  final String cancelText;

  /// チェックボックスを表示するか
  final bool showCheckbox;

  /// チェックボックス初期値
  final bool initialChecked;

  /// チェックボックスラベル
  final String checkboxLabel;

  /// 確定ボタン色
  final Color confirmColor;

  @override
  State<DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();

  /// static 呼び出し補助
  static Future<DeleteDialogResult?> show(
      BuildContext context, {
        required String title,
        required List<String> bulletPoints,
        String? description,
        String confirmText = '削除',
        String cancelText = 'キャンセル',
        bool showCheckbox = false,
        bool initialChecked = false,
        String checkboxLabel = '',
        Color confirmColor = Colors.redAccent,
      }) {
    return showDialog<DeleteDialogResult>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: title,
        bulletPoints: bulletPoints,
        description: description,
        confirmText: confirmText,
        cancelText: cancelText,
        showCheckbox: showCheckbox,
        initialChecked: initialChecked,
        checkboxLabel: checkboxLabel,
        confirmColor: confirmColor,
      ),
    );
  }
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  late bool _checked = widget.initialChecked;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      title: Center(
        child: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(widget.description!,
                style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.bulletPoints
                  .map((e) => Text('• $e', style: const TextStyle(fontSize: 14)))
                  .toList(),
            ),
          ),

          /* ── bullet とボタンを分ける基本スペース 24px ── */
          const SizedBox(height: 24),

          /* ── チェックボックスがある場合のみ表示 ＋ 行の下に 8px 追加 ── */
          if (widget.showCheckbox) ...[
            InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () => setState(() => _checked = !_checked),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Checkbox(
                    value: _checked,
                    activeColor: AppColors.blue500,
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                    visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(widget.checkboxLabel,
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),   // ← チェックボックスとボタン群の間隔を 8px
          ],
        ],
      ),

      actions: [
        Row(
          children: [
            Expanded(                                   // ← 左ボタンを Expanded
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: AppColors.gray300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  const DeleteDialogResult(confirmed: false, checked: false),
                ),
                child: Text(widget.cancelText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(                                   // ← 右ボタンも Expanded
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  DeleteDialogResult(confirmed: true, checked: _checked),
                ),
                child: Text(widget.confirmText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
