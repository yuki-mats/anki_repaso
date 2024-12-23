import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class QuestionAddPage extends StatefulWidget {
  final DocumentReference folderRef;
  final DocumentReference questionSetRef;

  const QuestionAddPage({
    Key? key,
    required this.folderRef,
    required this.questionSetRef,
  }) : super(key: key);

  @override
  _QuestionAddPageState createState() => _QuestionAddPageState();
}

class _QuestionAddPageState extends State<QuestionAddPage> {
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController = TextEditingController();
  final TextEditingController _incorrectChoice1TextController = TextEditingController();
  final TextEditingController _incorrectChoice2TextController = TextEditingController();
  final TextEditingController _incorrectChoice3TextController = TextEditingController();
  final FocusNode _questionTextFocusNode = FocusNode();

  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _questionTextController.addListener(_onQuestionTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_questionTextFocusNode);
    });
  }

  @override
  void dispose() {
    _questionTextController.removeListener(_onQuestionTextChanged);
    _questionTextController.dispose();
    _correctChoiceTextController.dispose();
    _incorrectChoice1TextController.dispose();
    _incorrectChoice2TextController.dispose();
    _incorrectChoice3TextController.dispose();
    _questionTextFocusNode.dispose();
    super.dispose();
  }

  void _onQuestionTextChanged() {
    setState(() {
      _isSaveEnabled = _questionTextController.text.trim().isNotEmpty;
    });
  }

  void _clearFields() {
    _questionTextController.clear();
    _correctChoiceTextController.clear();
    _incorrectChoice1TextController.clear();
    _incorrectChoice2TextController.clear();
    _incorrectChoice3TextController.clear();

    setState(() {
      _trueFalseAnswer = true;
      _selectedQuestionType = 'true_false';
      _isSaveEnabled = false;
    });

    FocusScope.of(context).requestFocus(_questionTextFocusNode);
  }

  Future<void> _addQuestion() async {
    if (!_isSaveEnabled) return;

    // ユーザーのログイン状態をチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません。問題を保存するにはログインしてください。')),
      );
      return;
    }

    final folderRef = widget.folderRef;
    final questionSetRef = widget.questionSetRef;

    // データモデルに合わせて選択肢を設定
    final questionData = {
      'questionSetRef': questionSetRef,
      'questionText': _questionTextController.text.trim(),
      'questionType': 'true_false',
      'correctChoiceText': _trueFalseAnswer ? '正しい' : '間違い', // 正しい選択肢
      'incorrectChoice1Text': !_trueFalseAnswer ? '正しい' : '間違い', // 誤答選択肢
      'tags': [],
      'isFlagged': false,
      'notes': null,
      'examYear': null,
      'createdBy': FirebaseFirestore.instance.collection('users').doc(user.uid),
      'updatedBy': FirebaseFirestore.instance.collection('users').doc(user.uid),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('questions').add(questionData);

      // 質問数を更新
      await _updateQuestionCounts(folderRef, questionSetRef);

      _clearFields();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が保存されました')),
      );
    } catch (e) {
      print('Error saving question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の保存に失敗しました')),
      );
    }
  }

  Future<void> _updateQuestionCounts(
      DocumentReference folderRef, DocumentReference questionSetRef) async {
    try {
      // 問題集の質問数をカウント
      final questionSetCountSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', isEqualTo: questionSetRef)
          .count()
          .get();

      final questionSetTotalQuestions = questionSetCountSnapshot.count;

      // 問題集の質問数を更新
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(questionSetRef, {
          'questionCount': questionSetTotalQuestions,
          'updatedByRef': FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // フォルダの質問数を再計算
      final folderQuestionSetsSnapshot = await FirebaseFirestore.instance
          .collection('questionSets')
          .where('folderRef', isEqualTo: folderRef)
          .get();

      int folderTotalQuestions = 0;

      for (var doc in folderQuestionSetsSnapshot.docs) {
        final latestQuestionSetData = await FirebaseFirestore.instance
            .collection('questionSets')
            .doc(doc.id)
            .get();

        final latestQuestionCount = latestQuestionSetData.data()?['questionCount'] ?? 0;
        folderTotalQuestions += (latestQuestionCount as int);
      }

      // フォルダの質問数を更新
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(folderRef, {
          'questionCount': folderTotalQuestions,
          'updatedByRef': FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('質問数の更新に失敗しました')),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題作成'),
        actions: [
          TextButton(
            onPressed: _isSaveEnabled ? _addQuestion : null,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '保存',
                style: TextStyle(
                  color: _isSaveEnabled ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                _buildChip(
                  label: '正誤問題',
                  icon: Icons.check_circle_outline,
                  isSelected: _selectedQuestionType == 'true_false',
                  onTap: () {
                    setState(() {
                      _selectedQuestionType = 'true_false';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildChip(
                  label: '四択問題',
                  icon: Icons.list_alt,
                  isSelected: _selectedQuestionType == 'single_choice',
                  onTap: () {
                    setState(() {
                      _selectedQuestionType = 'single_choice';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildExpandableTextField(_questionTextController, '問題文'),
            const SizedBox(height: 16),
            if (_selectedQuestionType == 'true_false')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrueFalseSelectionTile(
                    label: '正しい',
                    value: true,
                    groupValue: _trueFalseAnswer,
                    onTap: () {
                      setState(() {
                        _trueFalseAnswer = true;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTrueFalseSelectionTile(
                    label: '間違い',
                    value: false,
                    groupValue: _trueFalseAnswer,
                    onTap: () {
                      setState(() {
                        _trueFalseAnswer = false;
                      });
                    },
                  ),
                ],
              ),
            if (_selectedQuestionType == 'single_choice') ...[
              _buildExpandableTextField(_correctChoiceTextController, '正解の選択肢'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_incorrectChoice1TextController, '誤答1'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_incorrectChoice2TextController, '誤答2'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_incorrectChoice3TextController, '誤答3'),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaveEnabled ? AppColors.blue500 : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaveEnabled ? _addQuestion : null,
                child: Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isSaveEnabled ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.blue500 : AppColors.gray200,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.blue500 : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.blue500 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrueFalseSelectionTile({
    required String label,
    required bool value,
    required bool groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.blue500 : AppColors.gray100,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.start,
          style: TextStyle(
            color: isSelected ? AppColors.blue500 : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableTextField(TextEditingController controller, String labelText) {
    return TextField(
      controller: controller,
      maxLines: null,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.grey),
        floatingLabelStyle: TextStyle(color: AppColors.blue700),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.gray50,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.gray50,
            width: 2.0,
          ),
        ),
      ),
    );
  }
}