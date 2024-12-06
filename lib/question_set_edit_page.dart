import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _questionSetNameController.text = widget.initialQuestionSetName; // 初期値を設定
    _questionSetNameController.addListener(() {
      updateButtonState(_questionSetNameController.text.trim().isNotEmpty);
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

  Future<void> _saveQuestionSet() async {
    final questionSetName = _questionSetNameController.text.trim();
    if (questionSetName.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('questionSets')
          .doc(widget.questionSetId) // 指定された問題集を更新
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集の編集'),
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
                  backgroundColor: _isButtonEnabled ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isButtonEnabled ? _saveQuestionSet : null,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void navigateToEditQuestionSetPage(
    BuildContext context, String folderId, String questionSetId, String initialQuestionSetName) {
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
