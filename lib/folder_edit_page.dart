import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class FolderEditPage extends StatefulWidget {
  final DocumentReference folderRef;
  final String initialFolderName;

  const FolderEditPage({
    Key? key,
    required this.folderRef,
    required this.initialFolderName,
  }) : super(key: key);

  @override
  _FolderEditPageState createState() => _FolderEditPageState();
}

class _FolderEditPageState extends State<FolderEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _folderNameController = TextEditingController();

  // フォーカス状態を管理するための FocusNode
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 初期値を設定
    _folderNameController.text = widget.initialFolderName;

    // 入力文字の変化を監視 → ボタン有効/無効の更新
    _folderNameController.addListener(() {
      final currentText = _folderNameController.text.trim();
      final initialText = widget.initialFolderName.trim();

      // 元の値と同じか空文字の場合はボタンを無効化
      // 元の値と異なる & 空でない場合のみ有効化
      updateButtonState(currentText.isNotEmpty && currentText != initialText);
    });

    // フォーカス状態の変化を監視 → 画面再描画
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  Future<void> _updateFolder() async {
    final folderName = _folderNameController.text.trim();
    if (folderName.isEmpty) return;

    try {
      await widget.folderRef.update({
        'name': folderName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByRef':
        FirebaseFirestore.instance.collection('users').doc('currentUserId'),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フォルダ名が更新されました')),
      );

      Navigator.of(context).pop(true); // 更新完了後、前の画面に戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 今のフォーカス状態
    final bool hasFocus = _focusNode.hasFocus;
    // テキスト入力の有無
    final bool hasText = _folderNameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('フォルダの編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // ★★ Containerで括り、枠線を透明にして同じサイズ・形状を再現
            Container(
              alignment: Alignment.center,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                // フォーカス時・非フォーカス時ともに無色の枠線
                border: Border.all(
                  color: Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: TextField(
                // フォーカス管理
                focusNode: _focusNode,
                controller: _folderNameController,
                autofocus: true,
                minLines: 1,
                maxLines: 1,
                style: const TextStyle(height: 1.5),
                cursorColor: AppColors.blue600,

                // 本来の外枠を消し、内部のラベルやヒントだけ使う
                decoration: InputDecoration(
                  // 中身は白色背景
                  filled: true,
                  fillColor: Colors.white,

                  // ラベル・ヒントの表示ロジック（フォーカスや入力状況による切り替え）
                  labelText: (hasFocus || hasText) ? 'フォルダ名' : null,
                  hintText: (!hasFocus && !hasText)
                      ? 'フォルダ名'
                      : (hasFocus && !hasText)
                      ? '例）製造基礎'
                      : null,
                  floatingLabelBehavior: FloatingLabelBehavior.auto,

                  // ラベル文字色は既存のまま
                  floatingLabelStyle: const TextStyle(
                    color: AppColors.blue600,
                  ),

                  // ★★ 枠線は全てなしに（透明化）
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isButtonEnabled ? AppColors.blue600 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? _updateFolder : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: _isButtonEnabled
                        ? Colors.white
                        : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
