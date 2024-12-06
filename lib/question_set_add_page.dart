import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';
import 'question_add_page.dart';

class QuestionSetsAddPage extends StatefulWidget {
  final String folderId;

  const QuestionSetsAddPage({Key? key, required this.folderId}) : super(key: key);

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
    setState(() {
      _isLoading = true; // ローディング状態を開始
    });

    try {
      final questionSetName = _questionSetNameController.text;

      // Firestoreに問題集を追加
      final questionSetRef = await FirebaseFirestore.instance
          .collection('questionSets') // トップのコレクションに追加
          .add({
        'name': questionSetName, // 問題集名
        'folder': FirebaseFirestore.instance.collection('folders').doc(widget.folderId), // 所属フォルダのリファレンス
        'createdBy': FirebaseFirestore.instance.collection('users').doc('currentUserId'), // 作成者のリファレンス（仮でcurrentUserIdを使っている）
        'createdAt': FieldValue.serverTimestamp(), // 作成日時
        'updatedAt': FieldValue.serverTimestamp(), // 更新日時
        'correctRate': 0, // 初期値
        'totalQuestions': 0, // 初期値
        'totalAttempts': 0, // 初期値
        'flaggedCount': 0, // 初期値
      });

      // Firestoreにデータが正常に追加された後、問題作成画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionAddPage(
            folderId: widget.folderId,
            questionSetId: questionSetRef.id, // 新しく作成された問題集のID
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
                labelText: 'サブカテゴリー名',
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
