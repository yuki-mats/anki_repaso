import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/completion_summary_page.dart';
import 'package:repaso/review_answers_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/image_preview_widget.dart';
import 'package:repaso/widgets/memory_level_buttons.dart';
import 'package:repaso/services/no_questions_widget.dart';
import 'package:repaso/widgets/choice_widgets.dart'; // ここに TrueFalseWidget, SingleChoiceWidget, FlashCardWidget などが含まれる
import 'package:repaso/services/answer_service.dart';

class StudySetAnswerPage extends StatefulWidget {
  final String studySetId; // StudySet の ID

  const StudySetAnswerPage({
    Key? key,
    required this.studySetId,
  }) : super(key: key);

  @override
  _StudySetAnswerPageState createState() => _StudySetAnswerPageState();
}

class _StudySetAnswerPageState extends State<StudySetAnswerPage> {
  List<Map<String, dynamic>> _questionsWithStats = []; // 各問題の情報（stats含む）
  List<Map<String, dynamic>> _answerResults = [];
  List<Map<String, dynamic>> _shuffledChoices = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  DateTime? _startedAt;
  DateTime? _answeredAt;
  String? _footerButtonType; // 'correct'（Hard/Good/Easy）または 'incorrect'（Next）

  // フラッシュカード用のフラグ
  bool _isFlashCardAnswerShown = false;
  bool _flashCardHasBeenRevealed = false;

  // スクロール制御用
  final ScrollController _scrollController = ScrollController();

  // StudySet 用のデフォルト参照（存在する場合）
  DocumentReference? _defaultFolderRef;
  DocumentReference? _defaultQuestionSetRef;
  String? _defaultQuestionSetName;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// StudySet の情報と対象の問題群を取得（フィルタ・ソート処理含む）
  Future<void> _fetchQuestions() async {
    try {
      // StudySet 情報の取得
      final studySetSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('studySets')
          .doc(widget.studySetId)
          .get();

      if (!studySetSnapshot.exists) {
        throw Exception('StudySet not found');
      }
      final studySetData = studySetSnapshot.data();
      if (studySetData == null) throw Exception('StudySet data is null');

      // studySet から対象の questionSet ID リスト等の設定を取得
      final List<String> questionSetIds = (studySetData['questionSetIds'] as List<dynamic>)
          .map((id) => id as String)
          .toList();
      final double? correctRateStart = studySetData['correctRateRange']?['start']?.toDouble();
      final double? correctRateEnd = studySetData['correctRateRange']?['end']?.toDouble();
      final bool flagFilterOn = studySetData['isFlagged'] ?? false;
      final String selectedOrder = studySetData['selectedQuestionOrder'] ?? 'random';
      final int numberOfQuestions = studySetData['numberOfQuestions'] ?? 10;

      // questionSet の名前および folderRef を取得
      final Map<String, String> questionSetNames = {};
      final Map<String, DocumentReference> questionSetFolderRefs = {};
      final questionSetDocs = await FirebaseFirestore.instance
          .collection('questionSets')
          .where(FieldPath.documentId, whereIn: questionSetIds)
          .get();

      for (var doc in questionSetDocs.docs) {
        final data = doc.data();
        questionSetNames[doc.id] = data['name'] ?? 'Unknown';
        if (data.containsKey('folderRef')) {
          questionSetFolderRefs[doc.id] = data['folderRef'] as DocumentReference;
        }
      }

      // 空状態用のデフォルト設定
      if (questionSetIds.isNotEmpty) {
        _defaultQuestionSetRef = FirebaseFirestore.instance.collection('questionSets').doc(questionSetIds.first);
        _defaultFolderRef = questionSetFolderRefs[questionSetIds.first];
        _defaultQuestionSetName = questionSetNames[questionSetIds.first];
      }

      // 対象の questions を取得（各 questionSet の参照を元に検索）
      final questionSnapshots = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetRef', whereIn: questionSetIds.map((id) =>
          FirebaseFirestore.instance.collection('questionSets').doc(id)))
          .where('isDeleted', isEqualTo: false)
          .get();

      // 各 question ごとにユーザー統計（questionUserStats）を取得し、フィルタ処理
      final filteredQuestions = await Future.wait(questionSnapshots.docs.map((doc) async {
        final statsSnapshot = await doc.reference
            .collection('questionUserStats')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .get();

        final Map<String, dynamic> questionData = doc.data() as Map<String, dynamic>;

        // デフォルトの統計情報
        Map<String, dynamic> statData = statsSnapshot.exists ? statsSnapshot.data() ?? {} : {
          'attemptCount': 0,
          'correctCount': 0,
          'incorrectCount': 0,
          'correctRate': 0.0,
          'isFlagged': false,
          'memoryLevelStats': {},
          'memoryLevelRatios': {},
        };

        // 正答率を計算
        final int attemptCount = statData['attemptCount'] ?? 0;
        final int correctCount = statData['correctCount'] ?? 0;
        final double computedCorrectRate = attemptCount > 0 ? correctCount / attemptCount : 0.0;
        statData['correctRate'] = computedCorrectRate;

        // 正答率フィルタ
        if (correctRateStart != null && correctRateEnd != null) {
          if (computedCorrectRate < correctRateStart || computedCorrectRate > correctRateEnd) {
            return null;
          }
        }

        // フラグフィルタ
        if (flagFilterOn && statData['isFlagged'] != true) {
          return null;
        }

        // questionSetName と folderRef を追加
        final DocumentReference questionSetRef = questionData['questionSetRef'] as DocumentReference;
        final String questionSetId = questionSetRef.id;
        final folderRef = questionSetFolderRefs[questionSetId];

        return {
          'questionId': doc.id,
          ...questionData,
          'statsData': statData,
          'questionSetName': questionSetNames[questionSetId] ?? 'Unknown',
          'questionSetRef': questionSetRef,
          'folderRef': folderRef,
        };
      }));

      // null を除去
      var validQuestions = filteredQuestions.whereType<Map<String, dynamic>>().toList();

      // 出題順のソート
      if (selectedOrder == 'random') {
        validQuestions.shuffle();
      } else if (selectedOrder == 'accuracyDescending') {
        validQuestions.sort((a, b) {
          final double aRate = a['statsData']['correctRate'] as double? ?? 0.0;
          final double bRate = b['statsData']['correctRate'] as double? ?? 0.0;
          return bRate.compareTo(aRate);
        });
      } else if (selectedOrder == 'accuracyAscending') {
        validQuestions.sort((a, b) {
          final double aRate = a['statsData']['correctRate'] as double? ?? 0.0;
          final double bRate = b['statsData']['correctRate'] as double? ?? 0.0;
          return aRate.compareTo(bRate);
        });
      }

      setState(() {
        _questionsWithStats = validQuestions.take(numberOfQuestions).toList();

        // 各問題の選択肢（true_false, single_choice 用）
        _shuffledChoices = _questionsWithStats.map((question) {
          if (question['questionType'] == 'true_false') {
            return {
              'questionId': question['questionId'],
              'choices': ['正しい', '間違い'],
            };
          } else if (question['questionType'] == 'single_choice') {
            List<String> choices = [
              question['correctChoiceText'] as String,
              question['incorrectChoice1Text'] as String,
              question['incorrectChoice2Text'] as String,
              question['incorrectChoice3Text'] as String,
            ].where((choice) => choice.isNotEmpty).toList();
            choices.shuffle(Random());
            return {
              'questionId': question['questionId'],
              'choices': choices,
            };
          } else {
            return {
              'questionId': question['questionId'],
              'choices': <String>[],
            };
          }
        }).toList();

        _isLoading = false;
        _startedAt = DateTime.now();
      });
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  /// 回答選択時の処理（選択肢ウィジェットから呼ばれる）
  void _handleAnswerSelection(BuildContext context, String selectedChoice) {
    final currentQuestion = _questionsWithStats[_currentQuestionIndex];
    final correctChoiceText = currentQuestion['correctChoiceText'];
    final questionId = currentQuestion['questionId'];

    setState(() {
      _selectedAnswer = selectedChoice;
      _isAnswerCorrect = (correctChoiceText == selectedChoice);
      _answeredAt = DateTime.now();
      _answerResults.add({
        'index': _currentQuestionIndex + 1,
        'questionId': questionId,
        'questionText': currentQuestion['questionText'] ?? '質問内容不明',
        'correctAnswer': correctChoiceText ?? '正解不明',
        'isCorrect': _isAnswerCorrect!,
      });
    });

    _showFeedbackAndNextQuestion(
      _isAnswerCorrect!,
      currentQuestion['questionText'],
      correctChoiceText,
      selectedChoice,
    );
  }

  /// 選択後のフィードバック表示（フッターのボタン表示切替など）
  void _showFeedbackAndNextQuestion(
      bool isAnswerCorrect, String questionText, String correctChoiceText, String selectedAnswer) {
    setState(() {
      _isAnswerCorrect = isAnswerCorrect;
      _footerButtonType = isAnswerCorrect ? 'correct' : 'incorrect';
    });
  }

  /// 次の問題へ遷移
  void _nextQuestion(DateTime nextStartedAt) {
    if (_currentQuestionIndex < _questionsWithStats.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
        _startedAt = nextStartedAt;
        // フラッシュカードの場合は、次の問題では初期表示（問題文）に戻す
        _isFlashCardAnswerShown = false;
        _flashCardHasBeenRevealed = false;
      });
    } else {
      _navigateToCompletionSummaryPage();
    }
  }

  /// 完了画面へ遷移
  void _navigateToCompletionSummaryPage() {
    final totalQuestions = _questionsWithStats.length;
    final correctAnswers = _answerResults.where((result) => result['isCorrect'] == true).length;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompletionSummaryPage(
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          incorrectAnswers: totalQuestions - correctAnswers,
          answerResults: _answerResults,
          onViewResults: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewAnswersPage(results: _answerResults),
              ),
            );
          },
          onExit: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// フラグ切替（ブックマーク）の処理
  Future<void> _toggleFlag() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final currentQuestion = _questionsWithStats[_currentQuestionIndex];
      final questionId = currentQuestion['questionId'];
      final questionUserStatsRef = FirebaseFirestore.instance
          .collection('questions')
          .doc(questionId)
          .collection('questionUserStats')
          .doc(user.uid);
      final currentFlagState = currentQuestion['statsData']['isFlagged'] ?? false;
      final newFlagState = !currentFlagState;
      await questionUserStatsRef.set({
        'isFlagged': newFlagState,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() {
        _questionsWithStats[_currentQuestionIndex]['statsData']['isFlagged'] = newFlagState;
      });
    } catch (e) {
      print('Error toggling flag: $e');
    }
  }

  /// ヒント表示ダイアログ
  void _showHintDialog() {
    final currentQuestion = _questionsWithStats[_currentQuestionIndex];
    final hintText = currentQuestion['hintText'] ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ヒント'),
          content: Text(hintText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  /// 解説表示ダイアログ
  void _showExplanationDialog() {
    final currentQuestion = _questionsWithStats[_currentQuestionIndex];
    final explanationText = currentQuestion['explanationText'] ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('解説'),
          content: Text(explanationText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
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
          'あと${_questionsWithStats.length - _currentQuestionIndex}問',
          style: const TextStyle(color: AppColors.gray700),
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation(AppColors.blue500),
        ),
      )
          : _questionsWithStats.isEmpty
          ? buildNoQuestionsWidget(
        context: context,
        message: '問題がありません',
        subMessage: '最初の問題を作成しよう',
        buttonMessage: '作成する',
        onPressed: () {
          // 必要に応じて作成画面へ遷移
        },
      )
          : Column(
        children: [
          // 進捗バー
          Row(
            children: getProgressColors(
              totalQuestions: _questionsWithStats.length,
              answerResults: _answerResults,
            ).map((color) => Expanded(child: Container(height: 10, color: color)))
                .toList(),
          ),
          // 質問・画像・各種アイコンを含むスクロールエリア
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 16.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.48,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: 12.0, left: 12.0, right: 12.0),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding:
                                    const EdgeInsets.only(right: 16.0),
                                    child: Text(
                                      _questionsWithStats[_currentQuestionIndex]
                                      ['questionSetName'] ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          Builder(builder: (context) {
                                            final currentQuestion = _questionsWithStats[_currentQuestionIndex];
                                            final questionType = currentQuestion['questionType'];
                                            // フラッシュカードの場合、答えが開示済みなら正解文・画像、それ以外は通常の問題文・画像を表示
                                            final displayText = (questionType == 'flash_card' && _isFlashCardAnswerShown)
                                                ? currentQuestion['correctChoiceText'] ?? ''
                                                : currentQuestion['questionText'] ?? '';
                                            final displayImageUrls = (questionType == 'flash_card' && _isFlashCardAnswerShown)
                                                ? List<String>.from(currentQuestion['correctChoiceImageUrls'] ??
                                                    [])
                                                : List<String>.from(currentQuestion['questionImageUrls'] ??
                                                    []);
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  displayText,
                                                  style: const TextStyle(fontSize: 12),
                                                  textAlign: TextAlign.start,
                                                ),
                                                const SizedBox(height: 8),
                                                if (displayImageUrls.isNotEmpty)
                                                  ImagePreviewWidget(imageUrls: displayImageUrls),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      children: [
                                        const Text(
                                          '正答率',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        Builder(builder: (context) {
                                          // 現在の質問の statsData から correctRate を取得
                                          final statsData = _questionsWithStats[_currentQuestionIndex]['statsData'] as Map<String, dynamic>? ?? {};
                                          final double correctRate = statsData['correctRate'] ?? 0.0;

                                          return Text(
                                            '${(correctRate * 100).toStringAsFixed(0)}%', // パーセンテージ表示
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          );
                                        }),
                                        const SizedBox(height: 8),
                                      ],
                                    ),

                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_questionsWithStats[_currentQuestionIndex]['hintText']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ?? false)
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.all(0),
                                            constraints: const BoxConstraints(
                                              minWidth: 26,
                                              minHeight: 26,
                                            ),
                                            icon: const Icon(
                                              Icons.lightbulb_outline,
                                              size: 22,
                                              color: Colors.grey,
                                            ),
                                            onPressed: _showHintDialog,
                                          ),
                                        if (((_footerButtonType != null) || _flashCardHasBeenRevealed) && (_questionsWithStats[_currentQuestionIndex]['explanationText']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ??
                                                false))
                                          Padding(
                                            padding:
                                            const EdgeInsets.only(
                                                left: 8.0),
                                            child: IconButton(
                                              style: IconButton.styleFrom(
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.all(0),
                                              constraints: const BoxConstraints(
                                                minWidth: 26,
                                                minHeight: 26,
                                              ),
                                              icon: const Icon(
                                                Icons.description_outlined,
                                                size: 22,
                                                color: Colors.grey,
                                              ),
                                              onPressed:
                                              _showExplanationDialog,
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.all(0),
                                          constraints: const BoxConstraints(
                                            minWidth: 26,
                                            minHeight: 26,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_note_outlined,
                                            size: 26,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {},
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.all(0),
                                          constraints: const BoxConstraints(
                                            minWidth: 26,
                                            minHeight: 26,
                                          ),
                                          icon: Icon(
                                            _questionsWithStats[
                                            _currentQuestionIndex]
                                            ['statsData']
                                            ['isFlagged'] ==
                                                true
                                                ? Icons.bookmark
                                                : Icons.bookmark_outline,
                                            size: 22,
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
                  // 回答ウィジェット部分
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder(builder: (context) {
                      final currentQuestion =
                      _questionsWithStats[_currentQuestionIndex];
                      final questionType = currentQuestion['questionType'];
                      if (questionType == 'true_false') {
                        return TrueFalseWidget(
                          correctChoiceText:
                          currentQuestion['correctChoiceText'],
                          selectedChoiceText: _selectedAnswer ?? '',
                          handleAnswerSelection: _handleAnswerSelection,
                        );
                      } else if (questionType == 'single_choice') {
                        final currentChoicesMap = _shuffledChoices.firstWhere(
                                (item) =>
                            item['questionId'] ==
                                currentQuestion['questionId'],
                            orElse: () => {'choices': []});
                        final List<String> currentChoices =
                        List<String>.from(
                            currentChoicesMap['choices']);
                        return SingleChoiceWidget(
                          choices: currentChoices,
                          correctChoiceText:
                          currentQuestion['correctChoiceText'],
                          selectedAnswer: _selectedAnswer,
                          handleAnswerSelection: _handleAnswerSelection,
                        );
                      } else if (questionType == 'flash_card') {
                        return FlashCardWidget(
                          isAnswerShown: _isFlashCardAnswerShown,
                          onToggle: () {
                            setState(() {
                              if (!_flashCardHasBeenRevealed) {
                                _flashCardHasBeenRevealed = true;
                                _isFlashCardAnswerShown = true;
                                _answeredAt = DateTime.now();
                                final currentQuestionId =
                                currentQuestion['questionId'];
                                if (_answerResults.isEmpty ||
                                    _answerResults.last['questionId'] !=
                                        currentQuestionId) {
                                  _answerResults.add({
                                    'index': _currentQuestionIndex + 1,
                                    'questionId': currentQuestionId,
                                    'questionText': currentQuestion[
                                    'questionText'] ??
                                        '質問内容不明',
                                    'correctAnswer': currentQuestion[
                                    'correctChoiceText'] ??
                                        '正解不明',
                                    'isCorrect': null,
                                  });
                                }
                              } else {
                                _isFlashCardAnswerShown =
                                !_isFlashCardAnswerShown;
                              }
                            });
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _questionsWithStats.isNotEmpty
          ? buildFooterButtons(
        questionType: _questionsWithStats[_currentQuestionIndex.clamp(0, _questionsWithStats.length - 1)]['questionType'],
        isAnswerCorrect: _isAnswerCorrect,
        // flash_cardの場合は、一度回答が開示されていればフッターを常に表示する
        flashCardAnswerShown: _flashCardHasBeenRevealed,
        onMemoryLevelSelected: () {
          final nextStartedAt = DateTime.now();
          _nextQuestion(nextStartedAt);
          setState(() {
            _footerButtonType = null;
            // ※_flashCardHasBeenRevealed はそのまま維持（フッターを表示し続ける）
            _isFlashCardAnswerShown = false; // 次の問題では、初期表示は問題文に戻す
          });
        },
        onNextPressed: () {
          final nextStartedAt = DateTime.now();
          _answerResults.last['memoryLevel'] = 'again';
          saveAnswer(
            questionId: _questionsWithStats[_currentQuestionIndex]['questionId'],
            isAnswerCorrect: _isAnswerCorrect!,
            answeredAt: _answeredAt!,
            nextStartedAt: nextStartedAt,
            memoryLevel: _answerResults.last['memoryLevel'],
            questionSetRef: _questionsWithStats[_currentQuestionIndex]['questionSetRef'],
            folderRef: _questionsWithStats[_currentQuestionIndex]['folderRef'],
            selectedAnswer: _selectedAnswer ?? '',
            correctChoiceText: _questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
            startedAt: _startedAt,
          );
          _nextQuestion(nextStartedAt);
          setState(() {
            _footerButtonType = null;
          });
        },
        saveAnswer: (String memoryLevel) {
          final nextStartedAt = DateTime.now();
          bool isAnswerCorrect = memoryLevel != 'again';
          _answerResults.last['memoryLevel'] = memoryLevel;
          saveAnswer(
            questionId: _questionsWithStats[_currentQuestionIndex]['questionId'],
            isAnswerCorrect: isAnswerCorrect,
            answeredAt: _answeredAt!,
            nextStartedAt: nextStartedAt,
            memoryLevel: memoryLevel,
            questionSetRef: _questionsWithStats[_currentQuestionIndex]['questionSetRef'],
            folderRef: _questionsWithStats[_currentQuestionIndex]['folderRef'],
            selectedAnswer: _selectedAnswer ?? '',
            correctChoiceText: _questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
            startedAt: _startedAt,
          );
          setState(() {
            _footerButtonType = null;
          });
        },
      )
          : null,
    );
  }
}
