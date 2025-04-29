import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_add_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/add_page_widgets/name_imput.dart';

class QuestionSetsAddPage extends StatefulWidget {
  final String folderId; // DocumentReference ではなく String に変更

  const QuestionSetsAddPage({Key? key, required this.folderId}) : super(key: key);

  @override
  _QuestionSetsAddPageState createState() => _QuestionSetsAddPageState();
}

class _QuestionSetsAddPageState extends State<QuestionSetsAddPage> {
  bool _isButtonEnabled = false;
  bool _isLoading = false; // ローディング状態の管理
  final TextEditingController _questionSetNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // NameInputで使用するFocusNode

  @override
  void initState() {
    super.initState();
    // 入力があればボタンを有効にするロジック
    _questionSetNameController.addListener(() {
      updateButtonState(_questionSetNameController.text.isNotEmpty);
    });

    // FocusNodeの変化に合わせてUI再描画
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
      _isLoading = true;
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final questionSetName = _questionSetNameController.text;
      final userId = user.uid;

      // Firestoreに問題集を追加
      final questionSet = await FirebaseFirestore.instance
          .collection('questionSets')
          .add({
        'name': questionSetName,
        'folderId': widget.folderId, // folderId (String) を保存
        'questionCount': 0,
        'isDeleted': false,
        'createdById': userId,
        'updatedId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 作成後、問題追加画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionAddPage(
            folderId: widget.folderId, // String を渡すように変更
            questionSetId: questionSet.id,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題集の追加に失敗しました。再度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // 共通ウィジェットNameInputを利用
            NameInput(
              controller: _questionSetNameController,
              focusNode: _focusNode,
              labelText: '問題集名',
              hintText: '例）製造基礎',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isButtonEnabled ? AppColors.blue500 : Colors.grey,
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
