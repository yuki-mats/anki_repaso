import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/question_add_page.dart';
import 'package:repaso/review_answers_page.dart';
import 'app_colors.dart';
import 'completion_summary_page.dart';

class AnswerPage extends StatefulWidget {
  final String folderId;
  final String questionSetId;

  const AnswerPage({
    Key? key,
    required this.folderId,
    required this.questionSetId,
  }) : super(key: key);

  @override
  _AnswerPageState createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  List<DocumentSnapshot> _questions = [];
  List<bool> _answerResults = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  DateTime? _startedAt;
  DateTime? _answeredAt;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where(
        'folder',
        isEqualTo: FirebaseFirestore.instance.collection('folders').doc(widget.folderId),
      )
          .where(
        'questionSet',
        isEqualTo: FirebaseFirestore.instance.collection('questionSets').doc(widget.questionSetId),
      )
          .limit(10)
          .get();

      setState(() {
        _questions = snapshot.docs;
        if (_questions.isNotEmpty) {
          _startedAt = DateTime.now(); // 最初の問題表示時刻を記録
        }
      });
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }

  Future<void> _saveAnswer(String questionId, bool isAnswerCorrect, DateTime answeredAt, DateTime? nextStartedAt) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final answerTime = _startedAt != null
          ? answeredAt.difference(_startedAt!).inMilliseconds
          : 0;

      final postAnswerTime = nextStartedAt != null
          ? nextStartedAt.difference(answeredAt).inMilliseconds
          : 0;

      await FirebaseFirestore.instance.collection('answerHistories').add({
        'userRef': FirebaseFirestore.instance.collection('users').doc(user.uid),
        'questionRef': FirebaseFirestore.instance.collection('questions').doc(questionId),
        'startedAt': _startedAt,
        'answeredAt': answeredAt,
        'nextStartedAt': nextStartedAt,
        'answerTime': answerTime,
        'postAnswerTime': postAnswerTime,
        'isCorrect': isAnswerCorrect,
        'selectedChoices': _selectedAnswer,
        'correctChoices': _questions[_currentQuestionIndex]['correctChoiceText'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Answer saved successfully');
    } catch (e) {
      print('Error saving answer: $e');
    }
  }

  void _handleAnswerSelection(
      BuildContext context, String selectedChoice) {
    final correctChoiceText = _questions[_currentQuestionIndex]['correctChoiceText'];

    setState(() {
      _selectedAnswer = selectedChoice;
      _isAnswerCorrect = (correctChoiceText == selectedChoice);
      _answeredAt = DateTime.now(); // 解答時間を記録
      _answerResults.add(_isAnswerCorrect!); // 正誤を記録
    });

    // フィードバック表示
    _showFeedbackAndNextQuestion(
      _isAnswerCorrect!,
      _questions[_currentQuestionIndex]['questionText'],
      correctChoiceText,
      selectedChoice,
    );
  }


  void _showFeedbackAndNextQuestion(
      bool isAnswerCorrect, String questionText, String correctChoiceText, String selectedAnswer) {
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
                    Text('問題文：', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(questionText, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('正しい答え：', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(correctChoiceText, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('あなたの回答：', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(selectedAnswer, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nextStartedAt = DateTime.now(); // 次の問題表示時間を記録
                      _saveAnswer(
                        _questions[_currentQuestionIndex].id,
                        isAnswerCorrect,
                        _answeredAt!,
                        nextStartedAt,
                      );
                      Navigator.of(context).pop();
                      _nextQuestion(nextStartedAt);
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

  void _nextQuestion(DateTime nextStartedAt) {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
        _startedAt = nextStartedAt; // 次の問題の開始時間を記録
      });
    } else {
      _navigateToCompletionSummaryPage();
    }
  }

  void _navigateToCompletionSummaryPage() {
    final totalQuestions = _questions.length;
    final correctAnswers = _answerResults.where((result) => result).length;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompletionSummaryPage(
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          incorrectAnswers: totalQuestions - correctAnswers,
          onRetryAll: () {
            _retryAll(); // 全て再試行
          },
          onRetryIncorrect: () {
            _retryIncorrect(); // 間違いのみ再試行
          },
          onViewResults: () {
            // ReviewAnswersPageへの遷移を追加
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewAnswersPage(
                  results: _questions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;

                    return {
                      'isCorrect': _answerResults[index],
                      'questionText': question['questionText'],
                      'userAnswer': _selectedAnswer,
                      'correctAnswer': question['correctChoiceText'],
                    };
                  }).toList(),
                ),
              ),
            );
          },
          onExit: () {
            Navigator.pop(context); // ホーム画面などに戻る処理
          },
        ),
      ),
    );
  }


  void _retryAll() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _isAnswerCorrect = null;
      _answerResults.clear(); // 回答履歴をクリア
    });
  }

  void _retryIncorrect() {
    final incorrectQuestions = _questions
        .asMap()
        .entries
        .where((entry) => !_answerResults[entry.key]) // Use entry.key for the index
        .map((entry) => entry.value) // Use entry.value for the actual question
        .toList();

    setState(() {
      _questions = incorrectQuestions;
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _isAnswerCorrect = null;
      _answerResults.clear(); // 再試行用に履歴をクリア
    });
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
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '問題がありません',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '最初の問題を作成しよう',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => QuestionAddPage(
                          folderId: widget.folderId,
                          questionSetId: widget.questionSetId,
                        ),
                      ),
                    ),
                    child: const Text(
                      '作成する',
                      style: TextStyle(fontSize: 16, color: Colors.white),
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
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12.withOpacity(0.5)),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _questions[_currentQuestionIndex]['questionText'],
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _questions[_currentQuestionIndex]['questionType'] == 'true_false'
                ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildTrueFalseOption(
                    _questions[_currentQuestionIndex]['incorrectChoice1Text'],
                    _questions[_currentQuestionIndex]['correctChoiceText'],
                    _questions[_currentQuestionIndex].id,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrueFalseOption(
                    _questions[_currentQuestionIndex]['correctChoiceText'],
                    _questions[_currentQuestionIndex]['correctChoiceText'],
                    _questions[_currentQuestionIndex].id,
                  ),
                ),
              ],
            )
                : buildSingleChoiceWidget(
              context: context,
              questionText: _questions[_currentQuestionIndex]['questionText'],
              correctChoiceText: _questions[_currentQuestionIndex]['correctChoiceText'],
              incorrectChoice1Text: _questions[_currentQuestionIndex]['incorrectChoice1Text'],
              incorrectChoice2Text: _questions[_currentQuestionIndex]['incorrectChoice2Text'],
              incorrectChoice3Text: _questions[_currentQuestionIndex]['incorrectChoice3Text'],
              questionId: _questions[_currentQuestionIndex].id,
              handleAnswerSelection: _handleAnswerSelection,
            ),

          ),
        ],
      ),
    );
  }


  Widget _buildTrueFalseOption(String label, String correctChoiceText, String questionId) {
    final isSelected = _selectedAnswer == label;
    final isTrueOption = label == correctChoiceText;

    return GestureDetector(
      onTap: () {
        if (_selectedAnswer == null) {
          _handleAnswerSelection(context, label);
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


Widget buildSingleChoiceWidget({
  required BuildContext context,
  required String questionText,
  required String correctChoiceText,
  String? incorrectChoice1Text,
  String? incorrectChoice2Text,
  String? incorrectChoice3Text,
  required String questionId,
  required void Function(BuildContext context, String selectedChoice) handleAnswerSelection,
}) {
  List<String> getShuffledChoices() {
    final choices = [
      correctChoiceText,
      if (incorrectChoice1Text != null) incorrectChoice1Text,
      if (incorrectChoice2Text != null) incorrectChoice2Text,
      if (incorrectChoice3Text != null) incorrectChoice3Text,
    ];
    choices.shuffle(Random());
    return choices;
  }

  final shuffledChoices = getShuffledChoices();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...shuffledChoices.map((choice) {
        return GestureDetector(
          onTap: () {
            handleAnswerSelection(context, choice);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // 背景を白にする。
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.circle_outlined, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ],
  );
}
