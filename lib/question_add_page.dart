import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class QuestionCreationPage extends StatefulWidget {
  final String categoryId;
  final String subcategoryId;

  const QuestionCreationPage({
    Key? key,
    required this.categoryId,
    required this.subcategoryId,
  }) : super(key: key);

  @override
  _QuestionCreationPageState createState() => _QuestionCreationPageState();
}

class _QuestionCreationPageState extends State<QuestionCreationPage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  final FocusNode _questionFocusNode = FocusNode();

  String _selectedQuestionType = '正誤問題';
  bool _trueFalseAnswer = true;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_onQuestionTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_questionFocusNode);
    });
  }

  @override
  void dispose() {
    _questionController.removeListener(_onQuestionTextChanged);
    _questionController.dispose();
    _answerController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _questionFocusNode.dispose();
    super.dispose();
  }

  void _onQuestionTextChanged() {
    setState(() {
      _isSaveEnabled = _questionController.text.trim().isNotEmpty;
    });
  }

  Future<void> _saveQuestion() async {
    if (!_isSaveEnabled) return;

    final categoryRef = FirebaseFirestore.instance.collection('categories').doc(widget.categoryId);
    final subcategoryRef = categoryRef.collection('subcategories').doc(widget.subcategoryId);

    final questionData = {
      'type': _selectedQuestionType,
      'question': _questionController.text,
      'correctAnswer': _selectedQuestionType == '正誤問題'
          ? _trueFalseAnswer
          : _answerController.text,
      'options': _selectedQuestionType == '4択問題'
          ? [
        _answerController.text,
        _option1Controller.text,
        _option2Controller.text,
        _option3Controller.text
      ]
          : [],
      'categoryRef': categoryRef,
      'subcategoryRef': subcategoryRef,
    };

    await FirebaseFirestore.instance.collection('questions').add(questionData);
    _clearFields();

    // 保存成功時にスナックバーを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('問題を保存しました')),
    );
  }

  void _clearFields() {
    _questionController.clear();
    _answerController.clear();
    _option1Controller.clear();
    _option2Controller.clear();
    _option3Controller.clear();
    setState(() {
      _trueFalseAnswer = true;
      _selectedQuestionType = '正誤問題';
      _isSaveEnabled = false;
    });
    FocusScope.of(context).requestFocus(_questionFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題作成'),
        actions: [
          TextButton(
            onPressed: _isSaveEnabled ? _saveQuestion : null,
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
                  isSelected: _selectedQuestionType == '正誤問題',
                  onTap: () {
                    setState(() {
                      _selectedQuestionType = '正誤問題';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildChip(
                  label: '4択問題',
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
                onPressed: _isSaveEnabled ? _saveQuestion : null,
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
            color: AppColors.gray50, // 非フォーカス時の枠線の色
            width: 1.0,         // 枠線の太さ
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.gray50, // フォーカス時の枠線の色
            width: 2.0,               // 枠線の太さ
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
            color: isSelected ? AppColors.blue500 : AppColors.gray100,
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