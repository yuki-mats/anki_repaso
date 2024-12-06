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
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _correctChoiceTextController = TextEditingController();
  final TextEditingController _incorrectChoice1TextController = TextEditingController();
  final TextEditingController _incorrectChoice2TextController = TextEditingController();
  final TextEditingController _incorrectChoice3TextController = TextEditingController();

  String _selectedQuestionType = 'true_false';
  bool _trueFalseAnswer = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionData();
  }

  Future<void> _loadQuestionData() async {
    try {
      final questionDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .get();

      if (questionDoc.exists) {
        final data = questionDoc.data() as Map<String, dynamic>;

        setState(() {
          _questionTextController.text = data['questionText'] ?? '';
          _selectedQuestionType = data['questionType'] ?? 'true_false';

          if (_selectedQuestionType == 'true_false') {
            // 正誤問題の場合
            _trueFalseAnswer = data['correctChoiceText'] == '正しい';
          } else if (_selectedQuestionType == 'single_choice') {
            // 四択問題の場合
            _correctChoiceTextController.text = data['correctChoiceText'] ?? '';
            _incorrectChoice1TextController.text = data['incorrectChoice1Text'] ?? '';
            _incorrectChoice2TextController.text = data['incorrectChoice2Text'] ?? '';
            _incorrectChoice3TextController.text = data['incorrectChoice3Text'] ?? '';
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
      'questionText': _questionTextController.text.trim(),
      'questionType': _selectedQuestionType,
      'correctChoiceText': _selectedQuestionType == 'true_false'
          ? (_trueFalseAnswer ? '正しい' : '間違い')
          : _correctChoiceTextController.text.trim(),
      'incorrectChoice1Text': _selectedQuestionType == 'true_false'
          ? (!_trueFalseAnswer ? '正しい' : '間違い')
          : _incorrectChoice1TextController.text.trim(),
      'incorrectChoice2Text': _selectedQuestionType == 'single_choice'
          ? _incorrectChoice2TextController.text.trim()
          : null,
      'incorrectChoice3Text': _selectedQuestionType == 'single_choice'
          ? _incorrectChoice3TextController.text.trim()
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .update(questionData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題が更新されました')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題の更新に失敗しました')),
      );
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _correctChoiceTextController.dispose();
    _incorrectChoice1TextController.dispose();
    _incorrectChoice2TextController.dispose();
    _incorrectChoice3TextController.dispose();
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
              onPressed: _questionTextController.text.trim().isNotEmpty
                  ? _updateQuestion
                  : null,
              child: Text(
                '保存',
                style: TextStyle(
                  color: _questionTextController.text.trim().isNotEmpty
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
            color: Colors.grey,
            width: 0.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.blue300,
            width: 1.5,
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
            color: isSelected ? AppColors.blue500 : Colors.grey,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
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
