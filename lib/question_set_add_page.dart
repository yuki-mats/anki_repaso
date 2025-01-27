import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _questionSetNameController.addListener(() {
      updateButtonState(_questionSetNameController.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _questionSetNameController.dispose();
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
      _isLoading = true; // ローディング状態を開始
    });

    if (user == null) {
      // ユーザーがログインしていない場合の処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。')),
      );
      setState(() {
        _isLoading = false; // ローディング状態を終了
      });
      return; // 処理を終了
    }

    try {
      final questionSetName = _questionSetNameController.text;
      final userId = user.uid;

      // Firestoreに問題集を追加
      final questionSet = await FirebaseFirestore.instance
          .collection('questionSets') // トップのコレクションに追加
          .add({
        'name': questionSetName, // 問題集名
        'folderRef': widget.folderRef, // 所属フォルダのリファレンス
        'questionCount': 0, // 初期値
        "isDeleted": false, // 削除フラグ
        'createdByRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'updatedByRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'createdAt': FieldValue.serverTimestamp(), // 作成日時
        'updatedAt': FieldValue.serverTimestamp(), // 更新日時
      });

      // Firestoreにデータが正常に追加された後、問題作成画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionAddPage(
            folderRef: widget.folderRef,
            questionSetRef: questionSet, // 新しく作成された問題集のID
          ),
        ),
      );
    } catch (e) {
      // エラー時の処理（例: SnackBarでエラーを通知）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題集の追加に失敗しました。再度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false; // ローディング状態を終了
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しい問題集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _questionSetNameController,
              autofocus: true,
              minLines: 1,
              maxLines: 1,
              style: const TextStyle(height: 1.5),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                labelText: '問題集名',
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
