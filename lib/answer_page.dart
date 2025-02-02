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
  List<Map<String, dynamic>> questionsWithStats = [];
  List<Map<String, dynamic>> _answerResults = [];
  List<List<String>> _shuffledChoices = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  DateTime? _startedAt;
  DateTime? _answeredAt;
  String? _footerButtonType; // 現在のボタン状態 ('HardGoodEasy' or 'Next')
  bool _isLoading = true;

  // メモリレベルに応じた色を返す関数
  Color _getMemoryLevelColor(String level) {
    switch (level) {
      case 'unanswered':
        return Colors.grey[300]!;
      case 'again':
        return Colors.red[300]!;
      case 'hard':
        return Colors.orange[300]!;
      case 'good':
        return Colors.green[300]!;
      case 'easy':
        return Colors.blue[300]!;
      default:
        return Colors.grey;
    }
  }

  /// プログレスバーの色を「メモリレベルごと」にまとめて表示する関数
  List<Color> _getProgressColors() {
    final int totalQuestions = questionsWithStats.length;
    // 問題が0件の場合、灰色のみ
    if (totalQuestions == 0) {
      return [Colors.grey[300]!];
    }

    // メモリレベルごとに数をまとめる
    // 先に未回答分を計算しておく
    final Map<String, int> memoryLevelCounts = {
      'easy': 0,
      'good': 0,
      'hard': 0,
      'again': 0,
      // unanswered は「全問題数 - 回答済み数」
      'unanswered': totalQuestions - _answerResults.length,
    };

    // 回答済み分をメモリレベルごとにカウント
    for (var result in _answerResults) {
      String level = result['memoryLevel'] ?? 'unanswered';
      if (memoryLevelCounts.containsKey(level)) {
        memoryLevelCounts[level] = memoryLevelCounts[level]! + 1;
      } else {
        memoryLevelCounts[level] = 1;
      }
    }

    // メモリレベルごとにまとめて色を追加（左→右）
    // 順序はお好みで並べ替えてください
    List<String> levelOrder = ['again', 'hard', 'good', 'easy', 'unanswered'];

    List<Color> colors = [];
    for (String level in levelOrder) {
      int count = memoryLevelCounts[level] ?? 0;
      if (count > 0) {
        colors.addAll(List.filled(count, _getMemoryLevelColor(level)));
      }
    }
    return colors;
  }

  @override
  void initState() {
    super.initState();
    _loadQuestionsWithStats();
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

      choices.shuffle(Random());
      return choices;
    }).toList();

    setState(() {
      questionsWithStats = result;
      _shuffledChoices = shuffledChoices;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchQuestionsWithStats(
      DocumentReference questionSetRef, String userId) async {
    try {
      // 問題を10問取得
      QuerySnapshot questionSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', isEqualTo: questionSetRef)
          .where('isDeleted', isEqualTo: false)
          .limit(10)
          .get();

      List<DocumentReference> questionRefs =
      questionSnapshot.docs.map((doc) => doc.reference).toList();

      // 並列で questionUserStats を取得
      List<Future<DocumentSnapshot?>> statFutures = questionRefs.map((ref) {
        return ref
            .collection('questionUserStats')
            .doc(userId)
            .get()
            .then((doc) => doc.exists ? doc : null);
      }).toList();

      List<DocumentSnapshot?> statSnapshots = await Future.wait(statFutures);

      // データを結合して返却
      List<Map<String, dynamic>> questionsWithStats = [];
      for (int i = 0; i < questionRefs.length; i++) {
        final questionData =
        questionSnapshot.docs[i].data() as Map<String, dynamic>;
        final statData =
            statSnapshots[i]?.data() as Map<String, dynamic>? ?? {};

        questionsWithStats.add({
          'questionId': questionSnapshot.docs[i].id,
          ...questionData,
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

      return questionsWithStats;
    } catch (e) {
      print('Error fetching questions and stats: $e');
      return [];
    }
  }

  Future<void> _saveAnswer(
      String questionId,
      bool isAnswerCorrect,
      DateTime answeredAt,
      DateTime? nextStartedAt, {
        required String memoryLevel,
      }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userId = user.uid;
      final questionRef =
      FirebaseFirestore.instance.collection('questions').doc(questionId);
      final questionUserStatsRef =
      questionRef.collection('questionUserStats').doc(userId);
      final questionSetUserStatsRef =
      widget.questionSetRef.collection('questionSetUserStats').doc(userId);

      final answerTime = _startedAt != null
          ? answeredAt.difference(_startedAt!).inMilliseconds
          : 0;
      final postAnswerTime = nextStartedAt != null
          ? nextStartedAt.difference(answeredAt).inMilliseconds
          : 0;

      // answerHistories に保存
      await FirebaseFirestore.instance.collection('answerHistories').add({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'questionRef': questionRef,
        'questionSetRef': widget.questionSetRef,
        'startedAt': _startedAt,
        'answeredAt': answeredAt,
        'nextStartedAt': nextStartedAt,
        'answerTime': answerTime,
        'postAnswerTime': postAnswerTime,
        'isCorrect': isAnswerCorrect,
        'selectedChoice': _selectedAnswer,
        'correctChoice': questionsWithStats[_currentQuestionIndex]
        ['correctChoiceText'],
        'memoryLevel': memoryLevel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // questionUserStats の更新
      await questionUserStatsRef.set({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'memoryLevel': memoryLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // questionSetUserStats の更新
      await questionSetUserStatsRef.set({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'memoryLevels': {
          questionId: memoryLevel,  // Map形式で問題IDをキーとしたメモリレベルを保存
        },
        'lastStudiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // folderSetUserStats の更新
      final folderSetUserStatsRef =
      widget.folderRef.collection('folderSetUserStats').doc(userId);

      await folderSetUserStatsRef.set({
        'userRef': FirebaseFirestore.instance.collection('users').doc(userId),
        'memoryLevels': {
          questionId: memoryLevel, // 同じくフォルダ側に対しても記録
        },
        'lastStudiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 統計情報を集計して更新
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
      final questionRef =
      FirebaseFirestore.instance.collection('questions').doc(questionId);
      final historiesRef = FirebaseFirestore.instance.collection('answerHistories');

      int _calculateIsoWeekNumber(DateTime date) {
        final firstDayOfYear = DateTime(date.year, 1, 1);
        final firstThursday = firstDayOfYear
            .add(Duration(days: (4 - firstDayOfYear.weekday + 7) % 7));
        final weekNumber = ((date.difference(firstThursday).inDays) / 7).ceil() + 1;
        return weekNumber;
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final isoWeekNumber = _calculateIsoWeekNumber(now);
      final weekKey = '${now.year}-W${isoWeekNumber.toString().padLeft(2, '0')}';
      final monthKey = DateFormat('yyyy-MM').format(now);

      // attemptCount & correctCount
      final attemptQuery = historiesRef
          .where('userRef', isEqualTo: userRef)
          .where('questionRef', isEqualTo: questionRef);

      final attemptCountSnapshot = await attemptQuery.count().get();
      final attemptCount = attemptCountSnapshot.count ?? 0;

      final correctCountSnapshot =
      await attemptQuery.where('isCorrect', isEqualTo: true).count().get();
      final correctCount = correctCountSnapshot.count ?? 0;
      final correctRate = attemptCount > 0 ? (correctCount / attemptCount) : 0;

      final questionUserStatsRef = questionRef.collection('questionUserStats').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final questionUserStatsDoc = await transaction.get(questionUserStatsRef);

        if (!questionUserStatsDoc.exists) {
          transaction.set(questionUserStatsRef, {
            'userRef': userRef,
            'attemptCount': attemptCount,
            'correctCount': correctCount,
            'correctRate': correctRate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(questionUserStatsRef, {
            'attemptCount': attemptCount,
            'correctCount': correctCount,
            'correctRate': correctRate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      Future<Map<String, dynamic>> _aggregateStats(
          DateTime start, DateTime end) async {
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
        final totalPostAnswerTime =
            aggregateQuerySnapshot.getSum('postAnswerTime') ?? 0;
        final totalStudyTime = totalAnswerTime + totalPostAnswerTime;

        final correctCountSnapshot =
        await query.where('isCorrect', isEqualTo: true).count().get();
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
      final monthEnd =
      DateTime(now.year, now.month + 1).subtract(const Duration(seconds: 1));

      final dailyStats = await _aggregateStats(
          dateStart, dateStart.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
      final weeklyStats = await _aggregateStats(weekStart, weekEnd);
      final monthlyStats = await _aggregateStats(monthStart, monthEnd);

      Future<void> _updateStat(
          String collectionName,
          String key,
          Map<String, dynamic> stats,
          Map<String, dynamic> additionalFields,
          ) async {
        final questionUserStatsRef =
        questionRef.collection('questionUserStats').doc(user.uid);
        final statDocRef = questionUserStatsRef.collection(collectionName).doc(key);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final questionUserStatsDoc =
          await transaction.get(questionUserStatsRef);
          if (!questionUserStatsDoc.exists) {
            transaction.set(questionUserStatsRef, {
              'userRef': userRef,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          transaction.set(
            statDocRef,
            {
              ...stats,
              ...additionalFields,
              'attemptCount': stats['attemptCount'],
              'correctCount': stats['correctCount'],
              'incorrectCount': stats['incorrectCount'],
              'totalStudyTime': stats['totalStudyTime'],
              'totalAnswerTime': stats['totalAnswerTime'],
              'totalPostAnswerTime': stats['totalPostAnswerTime'],
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
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
    } catch (e) {
      print('Error updating stats using aggregation queries: $e');
    }
  }

  void _handleAnswerSelection(BuildContext context, String selectedChoice) {
    final correctChoiceText =
    questionsWithStats[_currentQuestionIndex]['correctChoiceText'];
    final questionText =
    questionsWithStats[_currentQuestionIndex]['questionText'];
    final questionId = questionsWithStats[_currentQuestionIndex]['questionId'];

    setState(() {
      _selectedAnswer = selectedChoice;
      _isAnswerCorrect = (correctChoiceText == selectedChoice);
      _answeredAt = DateTime.now();

      // 回答結果リストに追加
      _answerResults.add({
        'index': _currentQuestionIndex + 1,
        'questionId': questionId,
        'questionText': questionText ?? '質問内容不明',
        'correctAnswer': correctChoiceText ?? '正解不明',
        'isCorrect': _isAnswerCorrect!,
      });

      // デバッグ用ログ
      print('現在の回答結果: $_answerResults');
    });

    // 選択肢を選んだ後、ユーザーにフィードバックを出してボタンを表示
    _showFeedbackAndNextQuestion(
      _isAnswerCorrect!,
      questionText,
      correctChoiceText,
      selectedChoice,
    );
  }

  void _showFeedbackAndNextQuestion(
      bool isAnswerCorrect,
      String questionText,
      String correctChoiceText,
      String selectedAnswer,
      ) {
    setState(() {
      _isAnswerCorrect = isAnswerCorrect;
      // 正解なら Hard/Good/Easy ボタン、誤答なら Next ボタン
      _footerButtonType = isAnswerCorrect ? 'HardGoodEasy' : 'Next';
    });
  }

  void _nextQuestion(DateTime nextStartedAt) {
    if (_currentQuestionIndex < questionsWithStats.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
        _startedAt = nextStartedAt;
      });
    } else {
      _navigateToCompletionSummaryPage();
    }
  }

  void _navigateToCompletionSummaryPage() {
    final totalQuestions = questionsWithStats.length;
    final correctAnswers =
        _answerResults.where((result) => result['isCorrect'] == true).length;
    print('回答結果一覧: $_answerResults');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompletionSummaryPage(
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          incorrectAnswers: totalQuestions - correctAnswers,
          // ここで _answerResults を渡す
          answerResults: _answerResults,
          onViewResults: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewAnswersPage(
                  results: _answerResults,
                ), // 実際にレビューを表示するページへ
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

    final newFlagState =
    !questionsWithStats[_currentQuestionIndex]['isFlagged'];

    await questionUserStatsRef.set({
      'isFlagged': newFlagState,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      questionsWithStats[_currentQuestionIndex]['isFlagged'] = newFlagState;
    });
  }

  // ヒント表示用モーダル
  void _showHintDialog() {
    final question = questionsWithStats[_currentQuestionIndex];
    final hintText = question['hintText'] ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 角丸の大きさを調整
          ),
          backgroundColor: Colors.white,
          title: const Text('ヒント', style: TextStyle(
              color: Colors.black,
              fontSize: 16,)),
          content: Text(hintText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる', style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,)),
            ),
          ],
        );
      },
    );
  }

  // 解説表示用モーダル
  void _showExplanationDialog() {
    final question = questionsWithStats[_currentQuestionIndex];
    final explanationText = question['explanationText'] ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // 角丸の大きさを調整
          ),
          backgroundColor: Colors.white,
          title: const Text('解説', style: TextStyle(
            color: Colors.black,
            fontSize: 16,)),
          content: Text(explanationText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:const Text('閉じる', style: TextStyle(
                color: Colors.black87,
                fontSize: 14,)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'あと${questionsWithStats.length - _currentQuestionIndex}問',
          style: const TextStyle(color: AppColors.gray700),
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor:
          const AlwaysStoppedAnimation(AppColors.blue500),
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
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '最初の問題を作成しよう',
                  style: TextStyle(
                      fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
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
          // プログレスバー（メモリレベル順にまとまった色）
          Row(
            children: _getProgressColors()
                .map(
                  (color) => Expanded(
                child: Container(
                  height: 10,
                  color: color,
                ),
              ),
            )
                .toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(
                top: 16.0, left: 16.0, right: 16.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.only(left: 16.0, top: 16.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding:
                            const EdgeInsets.only(right: 16.0),
                            child: Text(
                              widget.questionSetName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              questionsWithStats[_currentQuestionIndex]
                              ['questionText'],
                              style:
                              const TextStyle(fontSize: 14),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  '正答率',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${questionsWithStats[_currentQuestionIndex]['accuracy']?.toStringAsFixed(0) ?? '-'}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (((_selectedAnswer == null) &&
                                    (questionsWithStats[
                                    _currentQuestionIndex]
                                    ['hintText']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                        false)) ||
                                    ((_selectedAnswer != null) &&
                                        (questionsWithStats[
                                        _currentQuestionIndex]
                                        ['explanationText']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                            false)))
                                  IconButton(
                                    icon: Icon(
                                      _selectedAnswer == null
                                          ? Icons.lightbulb_outline
                                          : Icons.description_outlined,
                                      size: 28,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      if (_selectedAnswer == null) {
                                        _showHintDialog();
                                      } else {
                                        _showExplanationDialog();
                                      }
                                    },
                                  ),
                                //メモするためのアイコンを設置
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_note_outlined,
                                    size: 28,
                                    color: Colors.grey,),
                                  onPressed: () {

                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    questionsWithStats[_currentQuestionIndex]
                                    ['isFlagged'] ==
                                        true
                                        ? Icons.bookmark
                                        : Icons.bookmark_outline,
                                    size: 28,
                                    color: Colors.grey,
                                  ),
                                  onPressed: _toggleFlag,
                                ),
                              ],
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
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0),
                child: questionsWithStats[_currentQuestionIndex]
                ['questionType'] ==
                    'true_false'
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTrueFalseWidget(
                      context: context,
                      correctChoiceText:
                      questionsWithStats[_currentQuestionIndex]
                      ['correctChoiceText'],
                      selectedChoiceText: _selectedAnswer ?? '',
                      questionId:
                      questionsWithStats[_currentQuestionIndex]
                      ['questionId'],
                      handleAnswerSelection:
                      _handleAnswerSelection,
                    ),
                  ],
                )
                    : buildSingleChoiceWidget(
                  context: context,
                  questionText:
                  questionsWithStats[_currentQuestionIndex]
                  ['questionText'],
                  correctChoiceText:
                  questionsWithStats[_currentQuestionIndex]
                  ['correctChoiceText'],
                  questionId:
                  questionsWithStats[_currentQuestionIndex]
                  ['questionId'],
                  handleAnswerSelection:
                  _handleAnswerSelection,
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
        decoration: BoxDecoration(
          color: Colors.white, // 背景色
          border: Border(
            top: BorderSide(color: Colors.green, width: 4.0), // 上端のみ緑の太線
          ),
        ),
        padding: const EdgeInsets.only(
          bottom: 32.0,
          left: 16.0,
          right: 16.0,
          top: 24.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          // 内部的に 'hard', 'good', 'easy' として保存
          children: ['Hard', 'Good', 'Easy'].map((displayText) {
            final memoryLevel = displayText.toLowerCase();

            // ボタン色とアイコンを切り替え
            Color buttonColor;
            IconData buttonIcon;
            switch (memoryLevel) {
              case 'easy':
                buttonColor = Colors.blue[300]!;
                buttonIcon = Icons.sentiment_satisfied_alt_outlined;
                break;
              case 'good':
                buttonColor = Colors.green[300]!;
                buttonIcon = Icons.sentiment_satisfied;
                break;
              case 'hard':
                buttonColor = Colors.orange[300]!;
                buttonIcon = Icons.sentiment_dissatisfied_outlined;
                break;
              default:
                buttonColor = Colors.grey;
                buttonIcon = Icons.help_outline;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    final nextStartedAt = DateTime.now();
                    // 直近の回答データにメモリレベルをセット
                    _answerResults[_answerResults.length - 1]
                    ['memoryLevel'] = memoryLevel;

                    // Firestoreにも保存
                    _saveAnswer(
                      questionsWithStats[_currentQuestionIndex]
                      ['questionId'],
                      _isAnswerCorrect!,
                      _answeredAt!,
                      nextStartedAt,
                      memoryLevel: memoryLevel,
                    );

                    _nextQuestion(nextStartedAt);
                    setState(() {
                      _footerButtonType = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // 中央揃え
                      mainAxisSize: MainAxisSize.min, // アイコン＋テキスト分の最小幅
                      children: [
                        Icon(buttonIcon, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          displayText,
                          style:
                          const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else if (_footerButtonType == 'Next') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white, // 背景色
          border: Border(
            top: BorderSide(color: Colors.redAccent, width: 4.0), // 上端のみ緑の太線
          ),
        ),
        padding: const EdgeInsets.only(
          bottom: 32.0,
          left: 16.0,
          right: 16.0,
          top: 24.0,
        ),
        child: ElevatedButton(
          onPressed: () {
            final nextStartedAt = DateTime.now();
            // 誤答時は memoryLevel を 'again' として保存
            _answerResults[_answerResults.length - 1]['memoryLevel'] = 'again';

            _saveAnswer(
              questionsWithStats[_currentQuestionIndex]['questionId'],
              _isAnswerCorrect!,
              _answeredAt!,
              nextStartedAt,
              memoryLevel: 'again',
            );
            _nextQuestion(nextStartedAt);
            setState(() {
              _footerButtonType = null;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '次へ',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildTrueFalseWidget({
    required BuildContext context,
    required String correctChoiceText,
    required String selectedChoiceText,
    required String questionId,
    required void Function(BuildContext context, String selectedChoice)
    handleAnswerSelection,
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
              color: Colors.white,
              border: Border.all(
                color: isAnswerSelected
                    ? (isCorrect && isSelected
                    ? Colors.green.shade300
                    : isIncorrect
                    ? Colors.red.shade300
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
                      ? Colors.red
                      : Colors.transparent)
                      : Colors.transparent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
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
    required void Function(BuildContext context, String selectedChoice)
    handleAnswerSelection,
  }) {
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
              color: Colors.white,
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
                    style: const TextStyle(fontSize: 14, color: Colors.black),
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
