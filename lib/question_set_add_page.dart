import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
import 'question_add_page.dart';

class QuestionSetsAddPage extends StatefulWidget {
  final DocumentReference folderRef;

  const QuestionSetsAddPage({Key? key, required this.folderRef}) : super(key: key);

  @override
  _QuestionSetsAddPageState createState() => _QuestionSetsAddPageState();
}

class _QuestionSetsAddPageState extends State<QuestionSetsAddPage> {
  bool _isButtonEnabled = false;
  bool _isLoading = false; // ローディング状態の管理
  final TextEditingController _questionSetNameController = TextEditingController();

  // ★★ UIでフォーカス状態を扱うため、FocusNodeを追加
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 入力があればボタンを有効にするロジック（既存）
    _questionSetNameController.addListener(() {
      updateButtonState(_questionSetNameController.text.isNotEmpty);
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

  Future<void> _addQuestionSet() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isLoading = true; // ローディング開始
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。')),
      );
      setState(() {
        _isLoading = false; // ローディング終了
      });
      return;
    }

    try {
      final questionSetName = _questionSetNameController.text;
      final userId = user.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Firestoreに問題集を追加
      final questionSet = await FirebaseFirestore.instance
          .collection('questionSets')
          .add({
        'name': questionSetName,
        'folderRef': widget.folderRef,
        'questionCount': 0,
        'isDeleted': false,
        'createdByRef': userRef,
        'updatedByRef': userRef,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 新規作成後、問題追加画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionAddPage(
            folderRef: widget.folderRef,
            questionSetRef: questionSet,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題集の追加に失敗しました。再度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false; // ローディング終了
      });
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
        title: const Text('新しい問題集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ★★ 既存のTextFieldをContainerで包んで、枠線を透明に
            Container(
              alignment: Alignment.center,
              height: 64, // 高さは必要に応じて調整可
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.transparent, // フォーカス時/非フォーカス時でも無色
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
                // もしカーソル色を変えたい場合はここで指定
                cursorColor: AppColors.blue500,

                decoration: InputDecoration(
                  // 背景を白に塗る
                  filled: true,
                  fillColor: Colors.white,

                  // フォーカス時 or テキストあり の場合のみラベル表示
                  labelText: (hasFocus || hasText) ? '問題集名' : null,

                  // フォーカス時かつ未入力 => 例）製造基礎
                  // 未フォーカスかつ未入力 => 問題集名
                  hintText: (!hasFocus && !hasText)
                      ? '問題集名'
                      : (hasFocus && !hasText)
                      ? '例）製造基礎'
                      : null,

                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  floatingLabelStyle: const TextStyle(color: AppColors.blue500),

                  // 枠線は消す
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
                  _isButtonEnabled ? AppColors.blue500 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onPressed: _isButtonEnabled && !_isLoading ? _addQuestionSet : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('保存', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
