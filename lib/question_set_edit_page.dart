import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class QuestionSetEditPage extends StatefulWidget {
  final String initialQuestionSetName;
  final String folderId;
  final String questionSetId;

  const QuestionSetEditPage({
    Key? key,
    required this.initialQuestionSetName,
    required this.folderId,
    required this.questionSetId,
  }) : super(key: key);

  @override
  _QuestionSetEditPageState createState() => _QuestionSetEditPageState();
}

class _QuestionSetEditPageState extends State<QuestionSetEditPage> {
  bool _isButtonEnabled = false;
  final TextEditingController _questionSetNameController = TextEditingController();

  // UIでフォーカス状態を扱うため FocusNode を追加
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 初期値を設定
    _questionSetNameController.text = widget.initialQuestionSetName;

    // ★★ 修正: 「空文字 or 同じ文字列」ならボタン無効、それ以外は有効にする
    _questionSetNameController.addListener(() {
      final currentText = _questionSetNameController.text.trim();
      final initialText = widget.initialQuestionSetName.trim();

      // 空でない && 初期値と異なる => true
      // 上記以外(空 or 同じ) => false
      final isEnabled = currentText.isNotEmpty && currentText != initialText;
      updateButtonState(isEnabled);
    });

    // フォーカス状態が変わればUI再描画
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _questionSetNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void updateButtonState(bool isEnabled) {
    setState(() {
      _isButtonEnabled = isEnabled;
    });
  }

  Future<void> _saveQuestionSet() async {
    final questionSetName = _questionSetNameController.text.trim();
    if (questionSetName.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('questionSets')
          .doc(widget.questionSetId)
          .update({
        'name': questionSetName,
        'updatedAt': FieldValue.serverTimestamp(), // 更新日時を記録
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題集が更新されました')),
      );

      Navigator.of(context).pop(true); // 保存後、前の画面に戻る
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題集の更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // フォーカス中かどうか
    final bool hasFocus = _focusNode.hasFocus;
    // テキスト入力があるかどうか
    final bool hasText = _questionSetNameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('問題集の編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ContainerでTextFieldを包んで枠線を消す (UIは既存どおり)
            Container(
              alignment: Alignment.center,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: TextField(
                focusNode: _focusNode,
                controller: _questionSetNameController,
                autofocus: true,
                minLines: 1,
                maxLines: 1,
                style: const TextStyle(height: 1.5),
                cursorColor: AppColors.blue500,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: (hasFocus || hasText) ? '問題集名' : null,
                  hintText: (!hasFocus && !hasText)
                      ? '問題集名'
                      : (hasFocus && !hasText)
                      ? '例）製造基礎'
                      : null,
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  floatingLabelStyle: const TextStyle(color: AppColors.blue500),
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
                  backgroundColor: _isButtonEnabled ? AppColors.blue500 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? _saveQuestionSet : null,
                child: const Text('保存', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 画面遷移の関数はそのまま
void navigateToEditQuestionSetPage(
    BuildContext context,
    String folderId,
    String questionSetId,
    String initialQuestionSetName,
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QuestionSetEditPage(
        initialQuestionSetName: initialQuestionSetName,
        folderId: folderId,
        questionSetId: questionSetId,
      ),
    ),
  );
}
