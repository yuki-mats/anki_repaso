import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/review_answers_page.dart';
import 'package:repaso/services/answer_service.dart';
import 'package:repaso/widgets/answer_page_widgets/no_questions_widget.dart';
import 'package:repaso/widgets/image_preview_widget.dart';
import 'package:repaso/widgets/answer_page_widgets/answer_page_common.dart';
import 'package:repaso/widgets/info_dialog.dart';
import 'package:repaso/screens/memo_list_page.dart';
import '../utils/app_colors.dart';
import 'completion_summary_page.dart';


class AnswerPage extends StatefulWidget {
  final String folderId;
  final String questionSetId;
  final String questionSetName;


  const AnswerPage({
    Key? key,
    required this.folderId,
    required this.questionSetId,
    required this.questionSetName,
  }) : super(key: key);

  @override
  _AnswerPageState createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  List<Map<String, dynamic>> _questionsWithStats = [];
  List<Map<String, dynamic>> _answerResults = [];
  List<List<String>> _shuffledChoices = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  DateTime? _startedAt;
  DateTime? _answeredAt;
  String? _footerButtonType; // 現在のボタン状態 ('correct' or 'incorrect')
  bool _isLoading = true;
  bool _isFlashCardAnswerShown = false;
  bool _flashCardHasBeenRevealed = false;
  final ScrollController _scrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    _loadQuestionsWithStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionsWithStats() async {
    final result = await fetchQuestionsWithStats(
      FirebaseFirestore.instance.collection('questionSets').doc(widget.questionSetId),
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
      _questionsWithStats = result;
      _shuffledChoices = shuffledChoices;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchQuestionsWithStats(
      DocumentReference questionSetRef, String userId) async {
    try {
      // `questionSetId` に紐づく問題を取得
      QuerySnapshot questionSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('questionSetId', isEqualTo: questionSetRef.id)
          .where('isDeleted', isEqualTo: false)
          .get();

      // 取得した問題リストをランダムに並び替え
      List<QueryDocumentSnapshot> shuffledQuestions = questionSnapshot.docs..shuffle(Random());

      // 各 `question` の `DocumentReference` をリスト化
      List<DocumentReference> questionRefs = shuffledQuestions.map((doc) => doc.reference).toList();

      // `questionUserStats` を並列取得
      List<Future<DocumentSnapshot?>> statFutures = questionRefs.map((ref) {
        return ref.collection('questionUserStats').doc(userId).get().then(
              (doc) => doc.exists ? doc : null,
        );
      }).toList();
      List<DocumentSnapshot?> statSnapshots = await Future.wait(statFutures);

      // データを統合
      List<Map<String, dynamic>> questionsWithStats = [];
      for (int i = 0; i < questionRefs.length; i++) {
        final questionData = shuffledQuestions[i].data() as Map<String, dynamic>;
        final statData = statSnapshots[i]?.data() as Map<String, dynamic>? ?? {};

        questionsWithStats.add({
          'questionId': shuffledQuestions[i].id,
          ...questionData,
          'examSource': questionData['examSource'] ?? '', // 🔹 `examSource` を追加
          'isOfficial': questionData['isOfficial'] ?? false,
          'isFlagged': statData['isFlagged'] ?? false,
          'attemptCount': statData['attemptCount'] ?? 0,
          'correctCount': statData['correctCount'] ?? 0,
          'correctRate': (statData['attemptCount'] != null &&
              statData['correctCount'] != null &&
              statData['attemptCount'] != 0)
              ? (statData['correctCount'] / statData['attemptCount']) * 100
              : null,
          'totalStudyTime': statData['totalStudyTime'] ?? 0,
          'memoryLevelStats': statData['memoryLevelStats'] ?? {},
          'memoryLevelRatios': statData['memoryLevelRatios'] ?? {},
          'questionImageUrls': List<String>.from(questionData['questionImageUrls'] ?? []),
          'correctChoiceImageUrls': List<String>.from(questionData['correctChoiceImageUrls'] ?? []),
          'explanationImageUrls': List<String>.from(questionData['explanationImageUrls'] ?? []),
          'hintImageUrls': List<String>.from(questionData['hintImageUrls'] ?? []),
          'memoCount': questionData['memoCount'] ?? 0,
        });
      }

      print(questionsWithStats);
      return questionsWithStats;
    } catch (e) {
      print('Error fetching questions and stats: $e');
      return [];
    }
  }


  void _handleAnswerSelection(BuildContext context, String selectedChoice) {
    final correctChoiceText =
    _questionsWithStats[_currentQuestionIndex]['correctChoiceText'];
    final questionText =
    _questionsWithStats[_currentQuestionIndex]['questionText'];
    final questionId = _questionsWithStats[_currentQuestionIndex]['questionId'];

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
      _footerButtonType = isAnswerCorrect ? 'correct' : 'incorrect';
    });
  }

  void _nextQuestion(DateTime nextStartedAt) {
    if (_currentQuestionIndex < _questionsWithStats.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswerCorrect = null;
        _startedAt = nextStartedAt;
        _isFlashCardAnswerShown = false;
        _flashCardHasBeenRevealed = false;
      });
    } else {
      _navigateToCompletionSummaryPage();
    }
  }

  void _navigateToCompletionSummaryPage() {
    final totalQuestions = _questionsWithStats.length;
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

    final questionId = _questionsWithStats[_currentQuestionIndex]['questionId'];
    final questionUserStatsRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .collection('questionUserStats')
        .doc(user.uid);

    final newFlagState =
    !_questionsWithStats[_currentQuestionIndex]['isFlagged'];

    await questionUserStatsRef.set({
      'isFlagged': newFlagState,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _questionsWithStats[_currentQuestionIndex]['isFlagged'] = newFlagState;
    });
  }

// ヒント表示用モーダル（画像付き）
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

// 解説表示用モーダル（画像付き）
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

  /// メモ一覧シートを表示する関数
  void _showMemoListSheet(String questionId, String questionSetId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true, // 下からスライドするページ遷移
        builder: (context) => MemoListPage(
          questionId: questionId,
          questionSetId: questionSetId,
        ),
      ),
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.blue500),
        ),
      )
          : _questionsWithStats.isEmpty
          ? buildNoQuestionsWidget(
        context: context,
        message: '問題を取得できませんでした。',
      )
          : Column(
        children: [
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
          // 以下、プログレスバー下部をスクロール可能に変更
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0,),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.48,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 14.0, right: 14.0),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Text(
                                      widget.questionSetName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // 問題文と画像の部分をスクロール可能にする
                                if (_questionsWithStats.isNotEmpty)
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _scrollController,
                                      thumbVisibility: false, // スクロール可能なときに常に表示
                                      child: SingleChildScrollView(
                                        controller: _scrollController, // スクロールを制御
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // 余白を統一
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // 自動調整
                                          children: [
                                            // flash_card の場合は表示を切り替え
                                            Builder(builder: (context) {
                                              final currentQuestion = _questionsWithStats[_currentQuestionIndex];
                                              final questionType = currentQuestion['questionType'];

                                              final displayText = (questionType == 'flash_card' && _isFlashCardAnswerShown)
                                                  ? currentQuestion['correctChoiceText'] ?? ''
                                                  : currentQuestion['questionText'] ?? '';

                                              final displayImageUrls = (questionType == 'flash_card' && _isFlashCardAnswerShown)
                                                  ? List<String>.from(currentQuestion['correctChoiceImageUrls'] ?? [])
                                                  : List<String>.from(currentQuestion['questionImageUrls'] ?? []);

                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    displayText,
                                                    style: const TextStyle(fontSize: 13.5, height: 1.6,),
                                                    textAlign: TextAlign.start,
                                                  ),
                                                  const SizedBox(height: 8), // 固定間隔
                                                  if (displayImageUrls.isNotEmpty)
                                                    ImagePreviewWidget(imageUrls: displayImageUrls),
                                                  if (_questionsWithStats.isNotEmpty)
                                                    Builder(
                                                      builder: (context) {
                                                        final examSource = _questionsWithStats[_currentQuestionIndex]['examSource'];
                                                        if (examSource != null && examSource.isNotEmpty) {
                                                          return Align(
                                                            alignment: Alignment.topRight,
                                                            child: Padding(
                                                              padding: const EdgeInsets.only(right: 16.0),
                                                              child: Text(
                                                                '出典：$examSource', // 🔹「出典：」を追加
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors.grey,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return const SizedBox.shrink(); // 🔹 examSource が空なら何も表示しない
                                                      },
                                                    ),
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
                                    return CommonQuestionFooter(
                                      /* --- AI 用コンテキスト ------------------------------ */
                                      questionId       : question['questionId'] as String,
                                      questionText     : question['questionText']     ?? '',
                                      correctChoiceText: question['correctChoiceText']?? '',
                                      explanationText  : question['explanationText']  ?? '',

                                      /* --- 既存スレッドがあれば ID を渡す（無ければ null） */
                                      aiMemoId : null,

                                      /* --- UI／統計 -------------------------------------- */
                                      correctRate              : question['correctRate'],
                                      totalAnswers             : question['attemptCount'],
                                      hintText                 : question['hintText'],
                                      footerButtonType         : _footerButtonType,
                                      flashCardHasBeenRevealed : _flashCardHasBeenRevealed,
                                      isFlagged                : question['isFlagged'] == true,
                                      isOfficial               : question['isOfficial'] == true,
                                      memoCount                : question['memoCount'],

                                      /* --- コールバック ---------------------------------- */
                                      onShowHintDialog        : _showHintDialog,
                                      onShowExplanationDialog : _showExplanationDialog,
                                      onToggleFlag            : _toggleFlag,
                                      onMemoPressed           : () {
                                        _showMemoListSheet(question['questionId'], widget.questionSetId);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder( // 🔷 Builder を追加してローカルの context を確保
                      builder: (context) {
                        final type = _questionsWithStats[_currentQuestionIndex]['questionType'];
                        if (type == 'true_false') {
                          return TrueFalseWidget( // 🔷 buildTrueFalseWidget() → TrueFalseWidget クラスに変更
                            correctChoiceText: _questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
                            selectedChoiceText: _selectedAnswer ?? '',
                            handleAnswerSelection: _handleAnswerSelection,
                          );
                        } else if (type == 'single_choice') {
                          return SingleChoiceWidget( // 🔷 buildSingleChoiceWidget() → SingleChoiceWidget クラスに変更
                            choices: _shuffledChoices[_currentQuestionIndex], // 🔷 choices を渡す
                            correctChoiceText: _questionsWithStats[_currentQuestionIndex]['correctChoiceText'],
                            selectedAnswer: _selectedAnswer, // 🔷 selectedAnswer へ変更
                            handleAnswerSelection: _handleAnswerSelection,
                          );
                        } else if (type == 'flash_card') {
                          return FlashCardWidget(
                            isAnswerShown: _isFlashCardAnswerShown,
                            onToggle: () {
                              setState(() {
                                if (!_flashCardHasBeenRevealed) {
                                  // 初回「答えを見る」押下時：回答時刻の設定＆回答結果レコード追加、かつフラグを立てる
                                  _flashCardHasBeenRevealed = true;
                                  _isFlashCardAnswerShown = true;
                                  _answeredAt = DateTime.now();
                                  final currentQuestionId = _questionsWithStats[_currentQuestionIndex]['questionId'];
                                  if (_answerResults.isEmpty ||
                                      _answerResults.last['questionId'] != currentQuestionId) {
                                    _answerResults.add({
                                      'index': _currentQuestionIndex + 1,
                                      'questionId': currentQuestionId,
                                      'questionText': _questionsWithStats[_currentQuestionIndex]['questionText'] ?? '質問内容不明',
                                      'correctAnswer': _questionsWithStats[_currentQuestionIndex]['correctChoiceText'] ?? '正解不明',
                                      'isCorrect': null, // メモリーレベル選択時に判定
                                    });
                                  }
                                } else {
                                  // 初回以降は、表示内容のみ切り替え
                                  _isFlashCardAnswerShown = !_isFlashCardAnswerShown;
                                }
                              });
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _questionsWithStats.isNotEmpty
          ? buildFooterButtons(
        questionType: _questionsWithStats[
        _currentQuestionIndex.clamp(0, _questionsWithStats.length - 1)]['questionType'],
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
            questionSetId: widget.questionSetId,
            folderId: widget.folderId,
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
            questionSetId: widget.questionSetId,
            folderId: widget.folderId,
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
