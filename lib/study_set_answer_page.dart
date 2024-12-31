import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repaso/review_answers_page.dart';
import 'app_colors.dart';
import 'completion_summary_page.dart';

class StudySetAnswerPage extends StatefulWidget {
  final String studySetId; // StudySetのID

  const StudySetAnswerPage({
    Key? key,
    required this.studySetId,
  }) : super(key: key);

  @override
  _StudySetAnswerPageState createState() => _StudySetAnswerPageState();
}

class _StudySetAnswerPageState extends State<StudySetAnswerPage> {
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
      final studySetSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('studySets')
          .doc(widget.studySetId) // StudySetのIDを使用
          .get();

      if (!studySetSnapshot.exists) {
        throw Exception('StudySet not found');
      }

      final studySetData = studySetSnapshot.data();
      if (studySetData == null) {
        throw Exception('StudySet data is null');
      }

      final List<String> questionSetIds = List<String>.from(studySetData['questionSetIds'] ?? []);
      final double correctRateStart = (studySetData['correctRateRange']?['start'] ?? 0).toDouble();
      final double correctRateEnd = (studySetData['correctRateRange']?['end'] ?? 100).toDouble();
      final String selectedOrder = studySetData['selectedQuestionOrder'] ?? 'random';
      final int numberOfQuestions = studySetData['numberOfQuestions'] ?? 10;

      final questionSnapshots = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', whereIn: questionSetIds.map((id) =>
          FirebaseFirestore.instance.collection('questionSets').doc(id)))
          .get();

      // フィルタリング：正答率範囲
      final filteredQuestions = await Future.wait(questionSnapshots.docs.map((doc) async {
        final statsSnapshot = await doc.reference.collection('questionUserStats')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .get();
        final correctRate = statsSnapshot.exists ? statsSnapshot['correctRate'] as double : null;

        if (correctRate == null || correctRate < correctRateStart || correctRate > correctRateEnd) {
          return null;
        }
        return doc;
      }));

      // フィルタリング結果をクリーンアップ
      final validQuestions = filteredQuestions.whereType<DocumentSnapshot>().toList();

      // 出題順のソート
      if (selectedOrder == 'random') {
        validQuestions.shuffle();
      } else if (selectedOrder == 'accuracyAscending') {
        validQuestions.sort((a, b) {
          final aStats = a['questionUserStats'];
          final bStats = b['questionUserStats'];
          return (aStats?['correctRate'] ?? 0).compareTo(bStats?['correctRate'] ?? 0);
        });
      } else if (selectedOrder == 'accuracyDescending') {
        validQuestions.sort((a, b) {
          final aStats = a['questionUserStats'];
          final bStats = b['questionUserStats'];
          return (bStats?['correctRate'] ?? 0).compareTo(aStats?['correctRate'] ?? 0);
        });
      }

      // 出題数に基づいて質問を絞り込む
      final limitedQuestions = validQuestions.take(numberOfQuestions).toList();

      setState(() {
        _questions = limitedQuestions;
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

      final userId = user.uid;
      final questionRef = FirebaseFirestore.instance.collection('questions').doc(questionId);
      final questionUserStatsRef = questionRef.collection('questionUserStats').doc(userId);

      // Calculate answer and post-answer times
      final answerTime = _startedAt != null
          ? answeredAt.difference(_startedAt!).inMilliseconds
          : 0;

      final postAnswerTime = nextStartedAt != null
          ? nextStartedAt.difference(answeredAt).inMilliseconds
          : 0;

      // Save answer history
      await FirebaseFirestore.instance.collection('answerHistories').add({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'questionRef': questionRef,
        'startedAt': _startedAt,
        'answeredAt': answeredAt,
        'nextStartedAt': nextStartedAt,
        'answerTime': answerTime,
        'postAnswerTime': postAnswerTime,
        'isCorrect': isAnswerCorrect,
        'selectedChoice': _selectedAnswer,
        'correctChoice': _questions[_currentQuestionIndex]['correctChoiceText'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Answer saved successfully.');

      // Fetch current stats
      final questionUserStatsSnapshot = await questionUserStatsRef.get();
      final currentStats = questionUserStatsSnapshot.exists ? questionUserStatsSnapshot.data() : {};

      // Extract or initialize stats
      final attemptCount = (currentStats?['attemptCount'] ?? 0) + 1;
      final correctCount = (currentStats?['correctCount'] ?? 0) + (isAnswerCorrect ? 1 : 0);
      final incorrectCount = attemptCount - correctCount;
      final correctRate = correctCount / attemptCount;

      print('Updated attemptCount: $attemptCount');
      print('Updated correctCount: $correctCount');
      print('Calculated correctRate: $correctRate');

      // Update user stats
      await questionUserStatsRef.set({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'attemptCount': attemptCount,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
        'correctRate': correctRate,
        'totalAnswerTime': (currentStats?['totalAnswerTime'] ?? 0) + answerTime,
        'totalPostAnswerTime': (currentStats?['totalPostAnswerTime'] ?? 0) + postAnswerTime,
        'lastStudiedAt': answeredAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('User stats updated successfully.');

      await _updateStatsUsingAggregation(questionId);

    } catch (e) {
      print('Error saving answer: $e');
    }
  }

  Future<void> _updateStatsUsingAggregation(String questionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final now = DateTime.now();

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final questionRef = FirebaseFirestore.instance.collection('questions').doc(questionId);
      final historiesRef = FirebaseFirestore.instance.collection('answerHistories');

      // ISO week calculation
      int _calculateIsoWeekNumber(DateTime date) {
        final firstDayOfYear = DateTime(date.year, 1, 1);
        final firstThursday = firstDayOfYear.add(Duration(days: (4 - firstDayOfYear.weekday + 7) % 7));
        final weekNumber = ((date.difference(firstThursday).inDays) / 7).ceil() + 1;
        return weekNumber;
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final isoWeekNumber = _calculateIsoWeekNumber(now);
      final weekKey = '${now.year}-W${isoWeekNumber.toString().padLeft(2, '0')}';
      final monthKey = DateFormat('yyyy-MM').format(now);

      // Step 1: Aggregate attemptCount and correctCount
      final attemptQuery = historiesRef
          .where('userRef', isEqualTo: userRef)
          .where('questionRef', isEqualTo: questionRef);

      final attemptCountSnapshot = await attemptQuery.count().get();
      final attemptCount = attemptCountSnapshot.count ?? 0;

      print('Attempt Count: $attemptCount');

      final correctCountSnapshot = await attemptQuery
          .where('isCorrect', isEqualTo: true)
          .count()
          .get();
      final correctCount = correctCountSnapshot.count ?? 0;

      print('Correct Count: $correctCount');

      // Step 2: Calculate correct rate
      final correctRate = attemptCount > 0 ? (correctCount / attemptCount) : 0;
      print('Correct Rate: $correctRate');

      // Step 3: Update /questionUserStats/{userId}
      final questionUserStatsRef = questionRef.collection('questionUserStats').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final questionUserStatsDoc = await transaction.get(questionUserStatsRef);

        if (!questionUserStatsDoc.exists) {
          // Create document if it does not exist
          transaction.set(questionUserStatsRef, {
            'userRef': userRef,
            'attemptCount': attemptCount,
            'correctCount': correctCount,
            'correctRate': correctRate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('questionUserStats document created');
        } else {
          // Update existing document
          transaction.update(questionUserStatsRef, {
            'attemptCount': attemptCount,
            'correctCount': correctCount,
            'correctRate': correctRate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('questionUserStats document updated');
        }
      });

      // Step 4: Existing aggregation logic
      Future<Map<String, dynamic>> _aggregateStats(DateTime start, DateTime end) async {
        final query = historiesRef
            .where('userRef', isEqualTo: userRef)
            .where('questionRef', isEqualTo: questionRef)
            .where('answeredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('answeredAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

        final aggregateQuerySnapshot = await query.aggregate(
          count(),
          sum('answerTime'),
          sum('postAnswerTime'),
        ).get();

        final attemptCount = aggregateQuerySnapshot.count ?? 0;
        final totalAnswerTime = aggregateQuerySnapshot.getSum('answerTime') ?? 0;
        final totalPostAnswerTime = aggregateQuerySnapshot.getSum('postAnswerTime') ?? 0;
        final totalStudyTime = totalAnswerTime + totalPostAnswerTime;

        final correctCountSnapshot = await query.where('isCorrect', isEqualTo: true).count().get();
        final correctCount = correctCountSnapshot.count ?? 0;
        final incorrectCount = attemptCount - correctCount;

        return {
          'attemptCount': attemptCount,
          'correctCount': correctCount,
          'incorrectCount': incorrectCount,
          'totalAnswerTime': totalAnswerTime,
          'totalPostAnswerTime': totalPostAnswerTime,
          'totalStudyTime': totalStudyTime,
        };
      }

      final dateStart = DateTime(now.year, now.month, now.day);
      final weekStart = dateStart.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(Duration(days: 6));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1).subtract(Duration(seconds: 1));

      final dailyStats = await _aggregateStats(dateStart, dateStart.add(Duration(hours: 23, minutes: 59, seconds: 59)));
      final weeklyStats = await _aggregateStats(weekStart, weekEnd);
      final monthlyStats = await _aggregateStats(monthStart, monthEnd);

      Future<void> _updateStat(String collectionName, String key, Map<String, dynamic> stats, Map<String, dynamic> additionalFields) async {
        final questionUserStatsRef = questionRef.collection('questionUserStats').doc(user.uid);
        final statDocRef = questionUserStatsRef.collection(collectionName).doc(key);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final questionUserStatsDoc = await transaction.get(questionUserStatsRef);
          if (!questionUserStatsDoc.exists) {
            transaction.set(questionUserStatsRef, {
              'userRef': userRef,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          transaction.set(statDocRef, {
            ...stats,
            ...additionalFields,
            'attemptCount': stats['attemptCount'],
            'correctCount': stats['correctCount'],
            'incorrectCount': stats['incorrectCount'],
            'totalStudyTime': stats['totalStudyTime'],
            'totalAnswerTime': stats['totalAnswerTime'],
            'totalPostAnswerTime': stats['totalPostAnswerTime'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }

      await _updateStat('dailyStats', dateKey, dailyStats, {
        'date': dateKey,
        'dateTimestamp': Timestamp.fromDate(dateStart),
      });

      await _updateStat('weeklyStats', weekKey, weeklyStats, {
        'week': weekKey,
        'weekStartTimestamp': Timestamp.fromDate(weekStart),
        'weekEndTimestamp': Timestamp.fromDate(weekEnd),
      });

      await _updateStat('monthlyStats', monthKey, monthlyStats, {
        'month': monthKey,
        'monthStartTimestamp': Timestamp.fromDate(monthStart),
        'monthEndTimestamp': Timestamp.fromDate(monthEnd),
      });

      print('Stats updated successfully using aggregation queries');
    } catch (e) {
      print('Error updating stats using aggregation queries: $e');
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
