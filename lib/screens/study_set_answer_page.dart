import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/completion_summary_page.dart';
import 'package:repaso/screens/memo_list_page.dart';
import 'package:repaso/screens/review_answers_page.dart';
import 'package:repaso/utils/app_colors.dart';
import 'package:repaso/widgets/image_preview_widget.dart';
import 'package:repaso/widgets/info_dialog.dart';
import 'package:repaso/widgets/answer_page_widgets/answer_page_common.dart'; // ここに TrueFalseWidget, SingleChoiceWidget, FlashCardWidget などが含まれる
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
      // ───────────────── StudySet を取得 ─────────────────
      final studySetSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('studySets')
          .doc(widget.studySetId)
          .get();

      if (!studySetSnapshot.exists) throw Exception('StudySet not found');
      final studySetData = studySetSnapshot.data();
      if (studySetData == null) throw Exception('StudySet data is null');

      // ───────────────── StudySet 設定値 ─────────────────
      final List<String> questionSetIds =
      List<String>.from(studySetData['questionSetIds'] ?? []);
      final double? correctRateStart =
      studySetData['correctRateRange']?['start']?.toDouble();
      final double? correctRateEnd =
      studySetData['correctRateRange']?['end']?.toDouble();
      final bool flagFilterOn = studySetData['isFlagged'] ?? false;
      final String selectedOrder =
          studySetData['selectedQuestionOrder'] ?? 'random';
      final int numberOfQuestions = studySetData['numberOfQuestions'] ?? 10;
      final List<String> selectedMemoryLevels = List<String>.from(
          studySetData['selectedMemoryLevels'] ??
              ['again', 'hard', 'good', 'easy']);
      final String correctChoiceFilter =
          studySetData['correctChoiceFilter'] ?? 'all'; // ★ 正誤フィルター

      // ───────────────── 参照情報の取得 ─────────────────
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
          questionSetFolderRefs[doc.id] =
          data['folderRef'] as DocumentReference<Object?>;
        }
      }

      // デフォルト参照（空のときの UI 用）
      if (questionSetIds.isNotEmpty) {
        _defaultQuestionSetRef =
            FirebaseFirestore.instance.collection('questionSets').doc(
              questionSetIds.first,
            );
        _defaultFolderRef = questionSetFolderRefs[questionSetIds.first];
        _defaultQuestionSetName = questionSetNames[questionSetIds.first];
      }

      // ───────────────── 質問を一括取得 ─────────────────
      final questionSnapshots = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetId', whereIn: questionSetIds)
          .where('isDeleted', isEqualTo: false)
          .get();

      // ───────────────── フィルタリング ─────────────────
      final filteredQuestions = await Future.wait(questionSnapshots.docs.map(
            (doc) async {
          final statsSnapshot = await doc.reference
              .collection('questionUserStats')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .get();

          final Map<String, dynamic> q = doc.data() as Map<String, dynamic>;

          // ── 統計情報（既読対策）
          final Map<String, dynamic> stat = statsSnapshot.exists
              ? statsSnapshot.data() ?? {}
              : {
            'attemptCount': 0,
            'correctCount': 0,
            'incorrectCount': 0,
            'correctRate': 0.0,
            'isFlagged': false,
            'memoryLevelStats': {},
            'memoryLevelRatios': {},
          };

          // 正答率計算
          final int attemptCount = stat['attemptCount'] ?? 0;
          final int correctCount = stat['correctCount'] ?? 0;
          final double rate =
          attemptCount > 0 ? (correctCount / attemptCount * 100) : 0.0;
          stat['correctRate'] = rate;

          // ────────── 各種フィルター ──────────
          // 記憶度
          final lastMemory = stat['memoryLevel'] as String?;
          if (lastMemory != null && !selectedMemoryLevels.contains(lastMemory)) {
            return null;
          }

          // 正答率
          if (correctRateStart != null &&
              correctRateEnd != null &&
              (rate < correctRateStart || rate > correctRateEnd)) {
            return null;
          }

          // フラグ
          if (flagFilterOn && stat['isFlagged'] != true) return null;

          // ★ 正誤フィルター（true_false のときだけ適用）
          if (correctChoiceFilter != 'all' && q['questionType'] == 'true_false') {
            final String answerText = q['correctChoiceText'] ?? '';
            if (correctChoiceFilter == 'correct' && answerText != '正しい') return null;
            if (correctChoiceFilter == 'incorrect' && answerText != '間違い')
              return null;
          }

          // 参照情報を付与
          final String qsid = q['questionSetId'];
          final folderRef = questionSetFolderRefs[qsid];

          return {
            'questionId': doc.id,
            ...q,
            'statsData': stat,
            'questionSetName': questionSetNames[qsid] ?? 'Unknown',
            'questionSetId': qsid,
            'folderId': folderRef?.id ?? '',
            'folderRef': folderRef,
            'memoCount': q['memoCount'] ?? 0,
          };
        },
      ));

      // ───────────────── ソート・抽選 ─────────────────
      var validQuestions =
      filteredQuestions.whereType<Map<String, dynamic>>().toList();

      if (selectedOrder == 'random') {
        validQuestions.shuffle();
      } else if (selectedOrder == 'accuracyDescending') {
        validQuestions.sort((a, b) =>
            (b['statsData']['correctRate'] ?? 0.0)
                .compareTo(a['statsData']['correctRate'] ?? 0.0));
      } else if (selectedOrder == 'accuracyAscending') {
        validQuestions.sort((a, b) =>
            (a['statsData']['correctRate'] ?? 0.0)
                .compareTo(b['statsData']['correctRate'] ?? 0.0));
      }

      // ───────────────── State 更新 ─────────────────
      setState(() {
        _questionsWithStats = validQuestions.take(numberOfQuestions).toList();

        // 選択肢生成
        _shuffledChoices = _questionsWithStats.map((q) {
          if (q['questionType'] == 'true_false') {
            return {
              'questionId': q['questionId'],
              'choices': ['正しい', '間違い'],
            };
          } else if (q['questionType'] == 'single_choice') {
            final List<String> choices = [
              q['correctChoiceText'] ?? '',
              q['incorrectChoice1Text'] ?? '',
              q['incorrectChoice2Text'] ?? '',
              q['incorrectChoice3Text'] ?? '',
            ]..removeWhere((c) => c.isEmpty);
            choices.shuffle(Random());
            return {
              'questionId': q['questionId'],
              'choices': choices,
            };
          }
          return {'questionId': q['questionId'], 'choices': <String>[]};
        }).toList();

        _isLoading = false;
        _startedAt = DateTime.now();
      });
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() => _isLoading = false);
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
  Future<void> _navigateToCompletionSummaryPage() async {
    final totalQuestions = _questionsWithStats.length;
    final correctAnswers = _answerResults.where((result) => result['isCorrect'] == true).length;

    // セッション終了時刻として現在時刻を設定
    final sessionEnd = DateTime.now();
    // 学習セッション開始時刻は _startedAt（null でなければ）
    if (_startedAt != null) {
      await updateStudySetStats(
      studySetId: widget.studySetId,
      userId: FirebaseAuth.instance.currentUser!.uid,
      answerResults: _answerResults,
      sessionStart: _startedAt!,
      sessionEnd: sessionEnd,
      );
    }

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
    final question = _questionsWithStats[_currentQuestionIndex];
    final hintText = question['hintText'] ?? '';
    // Firestore に保存済みのヒント画像URL（存在しない場合は空リスト）
    final hintImageUrls = List<String>.from(question['hintImageUrls'] ?? []);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return InfoDialog(
          title: 'ヒント',
          content: hintText,
          imageUrls: hintImageUrls,
        );
      },
    );
  }

  /// 解説表示ダイアログ
  void _showExplanationDialog() {
    final question = _questionsWithStats[_currentQuestionIndex];
    final explanationText = question['explanationText'] ?? '';
    // Firestore に保存済みの解説画像URL（存在しfない場合は空リスト）
    final explanationImageUrls = List<String>.from(question['explanationImageUrls'] ?? []);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return InfoDialog(
          title: '解説',
          content: explanationText,
          imageUrls: explanationImageUrls,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'あと${_questionsWithStats.length - _currentQuestionIndex}問',
          style: const TextStyle(color: AppColors.gray700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            // 現在のユーザーID
            final userId = FirebaseAuth.instance.currentUser?.uid;
            if (userId != null && _startedAt != null) {
              // セッション終了時刻として現在時刻を設定
              final sessionEnd = DateTime.now();
              await updateStudySetStats(
                studySetId: widget.studySetId,
                userId: userId,
                answerResults: _answerResults,
                sessionStart: _startedAt!,
                sessionEnd: sessionEnd,
              );
            }
            // 画面を閉じる
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation(AppColors.blue500),
        ),
      )
          : _questionsWithStats.isEmpty
          ? // テキストで対象の問題がありませんでした。と表示。buildNoQuestionsWidgetは使用しない。
          Center(
            child: Text('対象の問題がありませんでした。'),
          )
          : Column(
        children: [
          // 進捗バー
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),  // 両端を丸める
            child: Row(
              children: getProgressColors(
                totalQuestions: _questionsWithStats.length,
                answerResults: _answerResults,
              ).map((color) {
                return Expanded(
                  child: Container(
                    height: 8,
                    color: color,
                  ),
                );
              }).toList(),
            ),
          ),
          // 質問・画像・各種アイコンを含むスクロールエリア
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.48,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding:
                                    const EdgeInsets.only(right: 16.0),
                                    child: Text(
                                      _questionsWithStats[_currentQuestionIndex]['questionSetName'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
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
                                            final examSource = currentQuestion['examSource'] as String? ?? '';
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  displayText,
                                                  style: const TextStyle(fontSize: 13.5, height: 1.6,),
                                                  textAlign: TextAlign.start,
                                                ),
                                                const SizedBox(height: 8),
                                                if (examSource.isNotEmpty)
                                                  Align(
                                                    alignment: Alignment.topRight,
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(right: 16.0, top: 4.0),
                                                      child: Text(
                                                        '出典：$examSource',
                                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                      ),
                                                    ),
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
                                Builder(
                                  builder: (context) {
                                    final question = _questionsWithStats[_currentQuestionIndex];
                                    final statsData = question['statsData'] as Map<String, dynamic>? ?? {};
                                    final double correctRate = statsData['correctRate'] ?? 0.0;
                                    final int    attemptCount = statsData['attemptCount'] ?? 0;

                                    return CommonQuestionFooter(
                                      questionId: question['questionId'] as String,
                                      questionText     : question['questionText']     ?? '',
                                      correctChoiceText: question['correctChoiceText']?? '',
                                      explanationText  : question['explanationText']  ?? '',
                                      aiMemoId  : null,
                                      correctRate: correctRate,
                                      totalAnswers   : attemptCount,
                                      hintText: question['hintText'],
                                      footerButtonType: _footerButtonType,
                                      flashCardHasBeenRevealed: _flashCardHasBeenRevealed,
                                      isFlagged: question['statsData']['isFlagged'] == true,
                                      isOfficialQuestion: question['isOfficialQuestion'] == true,
                                      memoCount: question['memoCount'],
                                      onShowHintDialog: _showHintDialog,
                                      onShowExplanationDialog: _showExplanationDialog,
                                      onToggleFlag: _toggleFlag,
                                      onMemoPressed: () {
                                        final currentQuestion = _questionsWithStats[_currentQuestionIndex];
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            fullscreenDialog: true, // 下からスライドするページ遷移
                                            builder: (context) => MemoListPage(
                                              questionId: currentQuestion['questionId'],
                                              questionSetId: currentQuestion['questionSetId'],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder(builder: (context) {
                      final currentQuestion = _questionsWithStats[_currentQuestionIndex];
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
                                    'questionText': currentQuestion['questionText'] ?? '質問内容不明',
                                    'correctAnswer': currentQuestion['correctChoiceText'] ?? '正解不明',
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
                  ),
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
            questionSetId:_questionsWithStats[_currentQuestionIndex]['questionSetId'],
            folderId: _questionsWithStats[_currentQuestionIndex]['folderId'],
            isAnswerCorrect: _isAnswerCorrect!,
            answeredAt: _answeredAt!,
            nextStartedAt: nextStartedAt,
            memoryLevel: _answerResults.last['memoryLevel'],
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
            questionSetId: _questionsWithStats[_currentQuestionIndex]['questionSetId'],
            folderId: _questionsWithStats[_currentQuestionIndex]['folderId'],
            isAnswerCorrect: isAnswerCorrect,
            answeredAt: _answeredAt!,
            nextStartedAt: nextStartedAt,
            memoryLevel: memoryLevel,
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
