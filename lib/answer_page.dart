import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repaso/question_add_page.dart';
import 'package:repaso/review_answers_page.dart';
import 'app_colors.dart';
import 'completion_summary_page.dart';

class AnswerPage extends StatefulWidget {
  final DocumentReference folderRef;  //問題が無い場合は新規作成画面に遷移するために必要。
  final DocumentReference questionSetRef;
  final String questionSetName;

  const AnswerPage({
    Key? key,
    required this.folderRef,
    required this.questionSetRef,
    required this.questionSetName,
  }) : super(key: key);

  @override
  _AnswerPageState createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  List<Map<String, dynamic>> questionsWithStats = []; // 型を修正
  List<Map<String, dynamic>> _answerResults = [];
  List<List<String>> _shuffledChoices = []; // ランダム順序を保持
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  DateTime? _startedAt;
  DateTime? _answeredAt;
  String? _footerButtonType; // 現在のボタン状態 ('HardGoodEasy' or 'Next')
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadQuestionsWithStats(); // 新たに非同期処理を呼び出す
  }


  Future<void> _loadQuestionsWithStats() async {
    final result = await fetchQuestionsWithStats(
      widget.questionSetRef,
      FirebaseAuth.instance.currentUser!.uid,
    );

    // 各問題の選択肢をシャッフル
    List<List<String>> shuffledChoices = result.map((question) {
      List<String> choices = [
        question['correctChoiceText'],
        question['incorrectChoice1Text'],
        question['incorrectChoice2Text'],
        question['incorrectChoice3Text']
      ].where((choice) => choice != null).cast<String>().toList();

      choices.shuffle(Random()); // ランダムに並び替え
      return choices;
    }).toList();

    setState(() {
      questionsWithStats = result; // 問題データを保存
      _shuffledChoices = shuffledChoices; // シャッフルされた選択肢を保存
      _isLoading = false; // ローディングを非表示に
    });
  }


  Future<List<Map<String, dynamic>>> fetchQuestionsWithStats(
      DocumentReference questionSetRef, String userId) async {
    try {
      // 問題を10問取得
      QuerySnapshot questionSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', isEqualTo: questionSetRef)
          .limit(10)
          .get();

      print("Fetched Questions:");
      for (var doc in questionSnapshot.docs) {
        print("Question ID: ${doc.id}, Data: ${doc.data()}");
      }

      // 取得した質問のリファレンス一覧を取得
      List<DocumentReference> questionRefs =
      questionSnapshot.docs.map((doc) => doc.reference).toList();
      print("Question References: ${questionRefs.map((ref) => ref.path).toList()}");

      // 並列でquestionUserStatsを取得
      List<Future<DocumentSnapshot?>> statFutures = questionRefs.map((ref) {
        return ref
            .collection('questionUserStats')
            .doc(userId)
            .get()
            .then((doc) => doc.exists ? doc : null);
      }).toList();

      List<DocumentSnapshot?> statSnapshots = await Future.wait(statFutures);

      print("Fetched Question User Stats:");
      for (int i = 0; i < statSnapshots.length; i++) {
        if (statSnapshots[i] != null) {
          print("Stats for Question ID: ${questionRefs[i].id}, Data: ${statSnapshots[i]!.data()}");
        } else {
          print("Stats for Question ID: ${questionRefs[i].id} not found.");
        }
      }

      // データを結合して返却
      List<Map<String, dynamic>> questionsWithStats = [];
      for (int i = 0; i < questionRefs.length; i++) {
        final questionData =
        questionSnapshot.docs[i].data() as Map<String, dynamic>; // 質問データ
        final statData =
            statSnapshots[i]?.data() as Map<String, dynamic>? ?? {}; // 統計データ

        // すべてのフィールドを結合
        questionsWithStats.add({
          'questionId': questionSnapshot.docs[i].id,
          ...questionData, // /questionsのすべてのフィールドを追加
          'isFlagged': statData['isFlagged'] ?? false,
          'attemptCount': statData['attemptCount'] ?? 0,
          'correctCount': statData['correctCount'] ?? 0,
          'accuracy': (statData['attemptCount'] != null &&
              statData['correctCount'] != null &&
              statData['attemptCount'] != 0)
              ? (statData['correctCount'] / statData['attemptCount']) * 100
              : null,
          'totalStudyTime': statData['totalStudyTime'] ?? 0,
          'memoryLevelStats': statData['memoryLevelStats'] ?? {},
          'memoryLevelRatios': statData['memoryLevelRatios'] ?? {},
        });
      }

      print("Combined Data (Questions with Stats):");
      for (var item in questionsWithStats) {
        print(item); // 各質問の詳細を表示
      }

      return questionsWithStats;
    } catch (e) {
      print('Error fetching questions and stats: $e');
      return [];
    }
  }

  Future<void> _saveAnswer(String questionId, bool isAnswerCorrect, DateTime answeredAt, DateTime? nextStartedAt,
      {required String memoryLevel}) async {
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
        'correctChoice': questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
        'memoryLevel': memoryLevel,
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

      // Update memoryLevelStats
      final memoryLevelStats = currentStats?['memoryLevelStats'] ?? {};
      memoryLevelStats[memoryLevel] = (memoryLevelStats[memoryLevel] ?? 0) + 1;

      // Calculate memory level ratios
      final memoryLevelRatios = memoryLevelStats.map((key, value) => MapEntry(key, (value / attemptCount) * 100));

      // Print updated stats and ratios
      print('Updated memory level stats: $memoryLevelStats');
      print('Updated memory level ratios: $memoryLevelRatios');

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
        'memoryLevelStats': memoryLevelStats,
        'memoryLevelRatios': memoryLevelRatios,
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
    final correctChoiceText = questionsWithStats[_currentQuestionIndex]['correctChoiceText'];
    final questionId = questionsWithStats[_currentQuestionIndex]['questionId'];

    setState(() {
      _selectedAnswer = selectedChoice;
      _isAnswerCorrect = (correctChoiceText == selectedChoice);
      _answeredAt = DateTime.now(); // 解答時間を記録
      _answerResults.add({
        'questionId': questionId,
        'isCorrect': _isAnswerCorrect!,
      }); // questionIdと正誤を記録
    });

    // フィードバック表示
    _showFeedbackAndNextQuestion(
      _isAnswerCorrect!,
      questionsWithStats[_currentQuestionIndex]['questionText'],
      correctChoiceText,
      selectedChoice,
    );
  }

  void _showFeedbackAndNextQuestion(
      bool isAnswerCorrect, String questionText, String correctChoiceText, String selectedAnswer) {
    setState(() {
      _isAnswerCorrect = isAnswerCorrect;
      _footerButtonType = isAnswerCorrect ? 'HardGoodEasy' : 'Next'; // ボタン種類を設定
    });
  }

  void _nextQuestion(DateTime nextStartedAt) {
    if (_currentQuestionIndex < questionsWithStats.length - 1) {
      // 次の問題に即時遷移
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
        _startedAt = nextStartedAt; // 次の問題の開始時間を記録
      });

      // Firestore処理をバックグラウンドで実行
      final nextQuestionId = questionsWithStats[_currentQuestionIndex]['questionId'];
    } else {
      _navigateToCompletionSummaryPage();
    }
  }
  void _navigateToCompletionSummaryPage() {
    final totalQuestions = questionsWithStats.length;
    final correctAnswers = _answerResults.where((result) => result['isCorrect'] == true).length;

    // _answerResultsの内容を出力
    print('Navigating to CompletionSummaryPage...');
    print('Answer Results: $_answerResults'); // ここで内容を確認

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompletionSummaryPage(
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          incorrectAnswers: totalQuestions - correctAnswers,
          onViewResults: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewAnswersPage(
                  results: questionsWithStats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;

                    return {
                      'isCorrect': _answerResults[index]['isCorrect'],
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


  Future<void> _toggleFlag() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final questionId = questionsWithStats[_currentQuestionIndex]['questionId'];
    final questionUserStatsRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .collection('questionUserStats')
        .doc(user.uid);

    // フラグ状態を切り替え
    final newFlagState = !questionsWithStats[_currentQuestionIndex]['isFlagged'];

    // Firestoreを更新
    await questionUserStatsRef.set({
      'isFlagged': newFlagState,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // UIを更新
    setState(() {
      questionsWithStats[_currentQuestionIndex]['isFlagged'] = newFlagState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(title: Text(
        //のこりの問題数を表示
        'あと${questionsWithStats.length - _currentQuestionIndex}問',
        style: const TextStyle(color: AppColors.gray700),
      )),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation(AppColors.blue500),
        ),
      )
          : questionsWithStats.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 240,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '問題がありません',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '最初の問題を作成しよう',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
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
                          folderRef: widget.folderRef,
                          questionSetRef: widget.questionSetRef,
                        ),
                      ),
                    ),
                    child: const Text(
                      '作成する',
                      style: TextStyle(fontSize: 18, color: Colors.white),
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
            value: (_currentQuestionIndex + 1) / questionsWithStats.length,
            minHeight: 10,
            backgroundColor: AppColors.gray50,
            valueColor: const AlwaysStoppedAnimation(AppColors.blue500),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.4, // 画面高さの40%を使用
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0,top: 16.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Text(widget.questionSetName,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(questionsWithStats[_currentQuestionIndex]['questionText'],
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '正答率',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                Text(
                                  '${questionsWithStats[_currentQuestionIndex]['accuracy']?.toStringAsFixed(0) ?? '-'}%',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                questionsWithStats[_currentQuestionIndex]['isFlagged'] == true ? Icons.bookmark : Icons.bookmark_outline,
                                size:28,
                                color: Colors.grey,
                              ),
                              onPressed: _toggleFlag, // アイコンをタップして状態を切り替え
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: questionsWithStats[_currentQuestionIndex]['questionType'] == 'true_false'
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 必要に応じて調整
                  children: [
                    buildTrueFalseWidget(
                      context: context,
                      correctChoiceText: questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
                      selectedChoiceText: _selectedAnswer ?? '',
                      questionId: questionsWithStats[_currentQuestionIndex]['questionId'],
                      handleAnswerSelection: _handleAnswerSelection,
                    ),
                  ],
                )
                    : buildSingleChoiceWidget(
                  context: context,
                  questionText: questionsWithStats[_currentQuestionIndex]['questionText'],
                  correctChoiceText: questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
                  questionId: questionsWithStats[_currentQuestionIndex]['questionId'],
                  handleAnswerSelection: _handleAnswerSelection,
                ),

              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooterButtons(),
    );
  }

  Widget _buildFooterButtons() {
    if (_footerButtonType == 'HardGoodEasy') {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 48.0, left: 16.0, right: 16.0, top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['Hard', 'Good', 'Easy'].map((level) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    final nextStartedAt = DateTime.now();
                    _saveAnswer(
                      questionsWithStats[_currentQuestionIndex]['questionId'],
                      _isAnswerCorrect!,
                      _answeredAt!,
                      nextStartedAt,
                      memoryLevel: level,
                    );
                    _nextQuestion(nextStartedAt); // 即時遷移
                    setState(() {
                      _footerButtonType = null; // ボタンを非表示に
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    level,
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else if (_footerButtonType == 'Next') {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 48.0, left: 16.0, right: 16.0, top: 16.0),
        child: ElevatedButton(
          onPressed: () {
            final nextStartedAt = DateTime.now();
            _saveAnswer(
              questionsWithStats[_currentQuestionIndex]['questionId'],
              _isAnswerCorrect!,
              _answeredAt!,
              nextStartedAt,
              memoryLevel: 'Again',
            );
            _nextQuestion(nextStartedAt); // 即時遷移
            setState(() {
              _footerButtonType = null; // ボタンを非表示に
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('次へ', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      );
    }
    return const SizedBox.shrink(); // ボタンがない場合は空
  }



  Widget buildTrueFalseWidget({
    required BuildContext context,
    required String correctChoiceText,
    required String selectedChoiceText,
    required String questionId,
    required void Function(BuildContext context, String selectedChoice) handleAnswerSelection,
  }) {
    final trueLabel = "正しい";
    final falseLabel = "間違い";

    final choices = [trueLabel, falseLabel];
    final isAnswerSelected = selectedChoiceText.isNotEmpty;

    List<Widget> choiceWidgets = [];

    for (String choice in choices) {
      final isSelected = selectedChoiceText == choice;
      final isCorrect = correctChoiceText == choice;
      final isIncorrect = isSelected && !isCorrect;

      choiceWidgets.add(
        GestureDetector(
          onTap: () {
            if (!isAnswerSelected) {
              handleAnswerSelection(context, choice);
            }
          },
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAnswerSelected
                  ? (isCorrect && isSelected
                  ? Colors.white
                  : isIncorrect
                  ? Colors.white
                  : Colors.white)
                  : Colors.white,
              border: Border.all(
                color: isAnswerSelected
                    ? (isCorrect && isSelected
                    ? Colors.green.shade300
                    : isIncorrect
                    ? Colors.orange.shade300
                    : isCorrect
                    ? Colors.green.shade300
                    : Colors.black26)
                    : Colors.black26,
                width: isSelected ? 2.0 : 1.0, // 修正: 選択された場合、枠線を太線に設定
                style: isAnswerSelected && isCorrect && !isSelected
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isAnswerSelected
                      ? (isCorrect
                      ? Icons.check
                      : isIncorrect
                      ? Icons.close
                      : null)
                      : null,
                  color: isAnswerSelected
                      ? (isCorrect
                      ? Colors.green
                      : isIncorrect
                      ? Colors.orange
                      : Colors.transparent)
                      : Colors.transparent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAnswerSelected && (isCorrect || isIncorrect)
                          ? Colors.black
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...choiceWidgets,
      ],
    );
  }

  Widget buildSingleChoiceWidget({
    required BuildContext context,
    required String questionText,
    required String correctChoiceText,
    required String questionId,
    required void Function(BuildContext context, String selectedChoice) handleAnswerSelection,
  }) {
    // 現在の質問のシャッフル済み選択肢を取得
    final currentChoices = _shuffledChoices[_currentQuestionIndex];
    final isAnswerSelected = _selectedAnswer != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: currentChoices.map((choice) {
        final isSelected = _selectedAnswer == choice;
        final isCorrect = choice == correctChoiceText;
        final isIncorrect = isSelected && !isCorrect;

        return GestureDetector(
          onTap: () {
            if (!isAnswerSelected) {
              handleAnswerSelection(context, choice);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAnswerSelected
                  ? (isCorrect && isSelected
                  ? Colors.white
                  : isIncorrect
                  ? Colors.white
                  : Colors.white)
                  : Colors.white,
              border: Border.all(
                color: isAnswerSelected
                    ? (isCorrect && isSelected
                    ? Colors.green.shade300
                    : isIncorrect
                    ? Colors.orange.shade300
                    : isCorrect
                    ? Colors.green.shade300
                    : Colors.black26)
                    : Colors.black26,
                width: isSelected ? 2.0 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isAnswerSelected
                      ? (isCorrect
                      ? Icons.check
                      : isIncorrect
                      ? Icons.close
                      : null)
                      : null,
                  color: isAnswerSelected
                      ? (isCorrect
                      ? Colors.green
                      : isIncorrect
                      ? Colors.orange
                      : Colors.transparent)
                      : Colors.transparent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAnswerSelected && (isCorrect || isIncorrect)
                          ? Colors.black
                          : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}