import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class QuestionEditPage extends StatefulWidget {
  final String questionId; // 編集する問題のID

  const QuestionEditPage({
    Key? key,
    required this.questionId,
  }) : super(key: key);

  @override
  _QuestionEditPageState createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends State<QuestionEditPage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();

  String _selectedQuestionType = '正誤問題';
  bool _trueFalseAnswer = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionData();
  }

  Future<void> _loadQuestionData() async {
    try {
      // Firestoreから指定された問題を取得
      DocumentSnapshot questionDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .get();

      if (questionDoc.exists) {
        Map<String, dynamic> data = questionDoc.data() as Map<String, dynamic>;

        setState(() {
          _questionController.text = data['question'] ?? '';
          _selectedQuestionType = data['type'] ?? '正誤問題';
          if (_selectedQuestionType == '正誤問題') {
            // correctAnswerをStringで扱うように変換
            _trueFalseAnswer = (data['correctAnswer'] == "true");
          } else {
            _answerController.text = data['options']?.first ?? '';
            _option1Controller.text = data['options']?[1] ?? '';
            _option2Controller.text = data['options']?[2] ?? '';
            _option3Controller.text = data['options']?[3] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading question data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuestion() async {
    final questionData = {
      'type': _selectedQuestionType,
      'question': _questionController.text,
      'correctAnswer': _selectedQuestionType == '正誤問題'
          ? (_trueFalseAnswer ? "true" : "false") // Stringとして保存
          : _answerController.text,
      'options': _selectedQuestionType == '4択問題'
          ? [
        _answerController.text,
        _option1Controller.text,
        _option2Controller.text,
        _option3Controller.text
      ]
          : [],
    };

    await FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.questionId)
        .update(questionData);

    // 保存成功時にスナックバーを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('問題を更新しました')),
    );
    Navigator.pop(context); // 前のページに戻る
  }

  void _clearFields() {
    // 入力フィールドをクリア
    _questionController.clear();
    _answerController.clear();
    _option1Controller.clear();
    _option2Controller.clear();
    _option3Controller.clear();

    // 状態を初期化
    setState(() {
      _trueFalseAnswer = true; // 正誤問題の初期値
      _selectedQuestionType = '正誤問題'; // 問題タイプをリセット
    });
  }


  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題編集'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _questionController.text.trim().isNotEmpty
                  ? _updateQuestion
                  : null,
              child: Text(
                '保存',
                style: TextStyle(
                  color: _questionController.text.trim().isNotEmpty
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
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
                  isSelected: _selectedQuestionType == '正誤問題',
                  onTap: () {
                    setState(() {
                      _selectedQuestionType = '正誤問題';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildChip(
                  label: '選択問題',
                  icon: Icons.list_alt,
                  isSelected: _selectedQuestionType == '4択問題',
                  onTap: () {
                    setState(() {
                      _selectedQuestionType = '4択問題';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildExpandableTextField(_questionController, '問題文'),
            const SizedBox(height: 16),
            if (_selectedQuestionType == '正誤問題')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectionTile(
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
                  _buildSelectionTile(
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
            if (_selectedQuestionType == '4択問題') ...[
              _buildExpandableTextField(_answerController, '正解の選択肢'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_option1Controller, '誤答1'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_option2Controller, '誤答2'),
              const SizedBox(height: 16),
              _buildExpandableTextField(_option3Controller, '誤答3'),
            ],
          ],
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
        labelStyle: const TextStyle(color: AppColors.gray300),
        floatingLabelStyle: TextStyle(color: AppColors.gray800),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.grey, // 非フォーカス時の枠線の色
            width: 0.1,         // 枠線の太さ
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.blue300, // フォーカス時の枠線の色
            width: 1.5,               // 枠線の太さ
          ),
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
            color: isSelected ? AppColors.blue500 : Colors.grey,
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

  Widget _buildSelectionTile({
    required String label,
    required bool value,
    required bool groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, // 横幅をいっぱいに広げる
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.blue500 : Colors.grey,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.start, // テキストを中央揃え
          style: TextStyle(
            color: isSelected ? AppColors.blue500 : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}