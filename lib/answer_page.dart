import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:repaso/question_add_page.dart';
import 'app_colors.dart';

class AnswerPage extends StatefulWidget {
  final String categoryId;
  final String subcategoryId;

  const AnswerPage({
    Key? key,
    required this.categoryId,
    required this.subcategoryId,
  }) : super(key: key);

  @override
  _AnswerPageState createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  List<DocumentSnapshot> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('questions')
        .where('categoryRef', isEqualTo: FirebaseFirestore.instance.collection('categories').doc(widget.categoryId))
        .where('subcategoryRef', isEqualTo: FirebaseFirestore.instance.collection('categories').doc(widget.categoryId).collection('subcategories').doc(widget.subcategoryId))
        .get();

    setState(() {
      _questions = snapshot.docs.take(10).toList();
    });
  }

  Future<void> _saveAnswer(String questionId, bool isAnswerCorrect) async {
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .collection('userAnswers')
        .add({
      'userAnswer': _selectedAnswer,
      'isAnswerCorrect': isAnswerCorrect,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _handleAnswerSelection(String questionId, String correctAnswer, String selectedAnswer) {
    bool isAnswerCorrect = (correctAnswer == selectedAnswer);

    setState(() {
      _selectedAnswer = selectedAnswer;
      _isAnswerCorrect = isAnswerCorrect;
    });
    _saveAnswer(questionId, isAnswerCorrect);

    final questionText = _questions[_currentQuestionIndex]['question'];
    _showFeedbackAndNextQuestion(isAnswerCorrect, questionText, correctAnswer, selectedAnswer);
  }

  void _showFeedbackAndNextQuestion(bool isAnswerCorrect, String questionText, String correctAnswer, String selectedAnswer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAnswerCorrect ? Colors.green : Colors.red,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Text(
                  isAnswerCorrect ? '正解！' : '不正解',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('問題文：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(questionText, style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('正しい答え：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(correctAnswer, style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('あなたの回答：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(selectedAnswer, style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _nextQuestion();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('次へ', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完了'),
        content: const Text('全ての問題に回答しました！'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> navigateToQuestionCreationPage(BuildContext context, String categoryId, String subcategoryId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionCreationPage(
          categoryId: categoryId,
          subcategoryId: subcategoryId,
        ),
      ),
    );
    _fetchQuestions(); // 戻った後に問題リストを更新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('問題に回答する')),
      body: _questions.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 240,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '問題がありません',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '最初の問題を作成しよう',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue500, // ボタンの背景色
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => navigateToQuestionCreationPage(context, widget.categoryId, widget.subcategoryId),
                    child: const Text(
                      '作成する',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            minHeight: 10,
            backgroundColor: Colors.black.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation(Colors.purple),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              height: 480,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12.withOpacity(0.5)),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _questions[_currentQuestionIndex]['question'],
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildTrueFalseOption("false", _questions[_currentQuestionIndex]['correctAnswer'], _questions[_currentQuestionIndex].id),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrueFalseOption("true", _questions[_currentQuestionIndex]['correctAnswer'], _questions[_currentQuestionIndex].id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrueFalseOption(String label, String correctAnswer, String questionId) {
    final isSelected = _selectedAnswer == label;
    final isTrueOption = label == "true";

    return GestureDetector(
      onTap: () {
        if (_selectedAnswer == null) {
          _handleAnswerSelection(questionId, correctAnswer, label);
        }
      },
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blueAccent.withOpacity(0.8) : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.blue600 : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Icon(
                isTrueOption ? Icons.check_circle : Icons.cancel,
                color: isSelected ? Colors.white : AppColors.blue600,
                size: 80,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.blue600,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
