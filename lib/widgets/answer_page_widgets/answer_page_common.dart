/*───────────────────────────────────────────────────────────────
  問題フッター ＋ 選択肢ウィジェット群（コピーしてそのまま置換 OK）
───────────────────────────────────────────────────────────────*/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:repaso/widgets/answer_page_widgets/chat_gpt_screen.dart';

/*───────────────────────────────────────────────────────────────
  共通フッター
───────────────────────────────────────────────────────────────*/
class CommonQuestionFooter extends StatelessWidget {
  /* 必須（AI ボタン用） */
  final String  questionId;
  final String  questionText;
  final String  correctChoiceText;
  final String  explanationText;

  /* 既存スレッドがあれば渡す（null なら新規） */
  final String? aiMemoId;

  /* UI／統計系 */
  final double?      correctRate;
  final String?      hintText;
  final String?      footerButtonType;
  final bool         flashCardHasBeenRevealed;
  final bool         isOfficialQuestion;
  final bool         isFlagged;
  final VoidCallback? onShowHintDialog;
  final VoidCallback? onShowExplanationDialog;
  final VoidCallback? onToggleFlag;
  final VoidCallback? onMemoPressed;
  final int?         memoCount;

  const CommonQuestionFooter({
    super.key,
    /* AI に必須 */
    required this.questionId,
    required this.questionText,
    required this.correctChoiceText,
    required this.explanationText,
    /* UI 必須 */
    required this.flashCardHasBeenRevealed,
    required this.isFlagged,
    required this.isOfficialQuestion,
    /* オプション */
    this.aiMemoId,
    this.correctRate,
    this.hintText,
    this.footerButtonType,
    this.onShowHintDialog,
    this.onShowExplanationDialog,
    this.onToggleFlag,
    this.onMemoPressed,
    this.memoCount,
  });

  /*──────── 共通丸ボタン ────────*/
  Widget _roundBtn(IconData icon, VoidCallback? onPressed) => Container(
    width: 34,
    height: 34,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
    child: IconButton(
      icon: Icon(icon, size: 22, color: Colors.grey),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    ),
  );

/*──────── AI ボタン ────────*/
  Widget _aiButton(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: _roundBtn(
      Icons.live_help_outlined,
          () => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.95,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SafeArea(
                  top: true,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        // ─── ヘッダー（×ボタン） ───
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        // ─── 本体 ───
                        Expanded(
                          child: ChatGPTScreen(
                            scrollController: scrollController,
                            questionId       : questionId,
                            questionText     : questionText,
                            correctChoiceText: correctChoiceText,
                            explanationText  : explanationText,
                            memoId           : aiMemoId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  /*──────── メモアイコン＋バッジ ────────*/
  Widget _memoIcon() => Stack(
    clipBehavior: Clip.none,
    children: [
      _roundBtn(Icons.edit_note_rounded, onMemoPressed),
      if (memoCount != null && memoCount! > 0)
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text('$memoCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ),
    ],
  );

  /*──────── BUILD ────────*/
  @override
  Widget build(BuildContext context) {
    final hasHint        = hintText?.trim().isNotEmpty ?? false;
    final hasExplanation = explanationText.trim().isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /* 左側：正答率 */
        Column(
          children: [
            const Text('正答率', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${correctRate?.toStringAsFixed(0) ?? '-'}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
          ],
        ),
        /* 右側：各種アクション */
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _aiButton(context),
            if (hasHint) ...[
              const SizedBox(width: 8),
              _roundBtn(Icons.lightbulb_outline, onShowHintDialog),
            ],
            if ((footerButtonType != null || flashCardHasBeenRevealed) && hasExplanation) ...[
              const SizedBox(width: 8),
              _roundBtn(Icons.description_outlined, onShowExplanationDialog),
            ],
            if (isOfficialQuestion) ...[
              const SizedBox(width: 8),
              _memoIcon(),
            ],
            const SizedBox(width: 8),
            _roundBtn(isFlagged ? Icons.bookmark : Icons.bookmark_outline, onToggleFlag),
          ],
        ),
      ],
    );
  }
}

/*───────────────────────────────────────────────────────────────
  True / False 選択肢
───────────────────────────────────────────────────────────────*/
class TrueFalseWidget extends StatelessWidget {
  final String correctChoiceText;
  final String selectedChoiceText;
  final void Function(BuildContext, String) handleAnswerSelection;

  const TrueFalseWidget({
    super.key,
    required this.correctChoiceText,
    required this.selectedChoiceText,
    required this.handleAnswerSelection,
  });

  @override
  Widget build(BuildContext context) {
    const trueLabel  = '正しい';
    const falseLabel = '間違い';
    final choices    = [trueLabel, falseLabel];
    final answered   = selectedChoiceText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: choices.map((c) {
        final selected  = selectedChoiceText == c;
        final correct   = correctChoiceText == c;
        final incorrect = selected && !correct;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (!answered) handleAnswerSelection(context, c);
          },
          child: _choiceBox(
            label     : c,
            selected  : selected,
            borderCol : answered
                ? (correct && selected)
                ? Colors.green.shade300
                : incorrect
                ? Colors.red.shade300
                : correct
                ? Colors.green.shade300
                : Colors.black26
                : Colors.black26,
            iconColor : answered
                ? (correct
                ? Colors.green
                : incorrect
                ? Colors.red
                : Colors.transparent)
                : Colors.transparent,
            icon      : answered
                ? (correct
                ? Icons.check
                : incorrect
                ? Icons.close
                : null)
                : null,
          ),
        );
      }).toList(),
    );
  }

  /* 共通レイアウト */
  Widget _choiceBox({
    required String label,
    required bool   selected,
    required Color  borderCol,
    required IconData? icon,
    required Color  iconColor,
  }) =>
      Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderCol, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

/*───────────────────────────────────────────────────────────────
  単一選択肢
───────────────────────────────────────────────────────────────*/
class SingleChoiceWidget extends StatelessWidget {
  final List<String> choices;
  final String correctChoiceText;
  final String? selectedAnswer;
  final void Function(BuildContext, String) handleAnswerSelection;

  const SingleChoiceWidget({
    super.key,
    required this.choices,
    required this.correctChoiceText,
    required this.selectedAnswer,
    required this.handleAnswerSelection,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selectedAnswer != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: choices.map((c) {
        final selected  = selectedAnswer == c;
        final correct   = c == correctChoiceText;
        final incorrect = selected && !correct;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (!answered) handleAnswerSelection(context, c);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: answered
                    ? selected
                    ? correct
                    ? Colors.green.shade300
                    : Colors.orange.shade300
                    : correct
                    ? Colors.green.shade300
                    : Colors.black26
                    : Colors.black26,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  answered
                      ? correct
                      ? Icons.check
                      : incorrect
                      ? Icons.close
                      : null
                      : null,
                  color: answered
                      ? correct
                      ? Colors.green
                      : incorrect
                      ? Colors.orange
                      : Colors.transparent
                      : Colors.transparent,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(c, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/*───────────────────────────────────────────────────────────────
  フラッシュカード
───────────────────────────────────────────────────────────────*/
class FlashCardWidget extends StatelessWidget {
  final bool isAnswerShown;
  final VoidCallback onToggle;

  const FlashCardWidget({
    super.key,
    required this.isAnswerShown,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onToggle();
    },
    child: Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(isAnswerShown ? '問題に戻る' : '答えを見る',
            style: const TextStyle(fontSize: 12)),
      ),
    ),
  );
}

/*───────────────────────────────────────────────────────────────
  フッターボタン群
───────────────────────────────────────────────────────────────*/
Widget buildFooterButtons({
  required String questionType,
  required bool? isAnswerCorrect,
  required bool   flashCardAnswerShown,
  required VoidCallback onMemoryLevelSelected,
  required VoidCallback onNextPressed,
  required Function(String) saveAnswer,
}) {
  if (questionType == 'flash_card') {
    if (!flashCardAnswerShown) return const SizedBox.shrink();
    return _memoryButtons(['Again', 'Hard', 'Good', 'Easy'], onMemoryLevelSelected, saveAnswer);
  }
  if (isAnswerCorrect == null)   return const SizedBox.shrink();
  if (isAnswerCorrect == true)   return _memoryButtons(['Hard', 'Good', 'Easy'], onMemoryLevelSelected, saveAnswer);
  return _nextBtn(onNextPressed);
}

/*──────── 内部ヘルパー ────────*/
Widget _memoryButtons(List<String> levels, VoidCallback onSelected, Function(String) save) =>
    Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.green, width: 4))),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: levels.map((l) {
          final lv   = l.toLowerCase();
          final data = _btnStyle(lv);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () {
                  save(lv);
                  onSelected();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: data['color'],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(data['icon'], size: 18, color: Colors.white),
                      const SizedBox(height: 4),
                      Text(l, style: const TextStyle(fontSize: 14, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

Widget _nextBtn(VoidCallback onNext) => Container(
  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.redAccent, width: 4))),
  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
  child: ElevatedButton(
    onPressed: onNext,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: const Text('次へ', style: TextStyle(fontSize: 18, color: Colors.white)),
  ),
);

Map<String, dynamic> _btnStyle(String lv) => switch (lv) {
  'again' => {'color': Colors.red[300],    'icon': Icons.refresh},
  'hard'  => {'color': Colors.orange[300], 'icon': Icons.sentiment_dissatisfied_outlined},
  'good'  => {'color': Colors.green[300],  'icon': Icons.sentiment_satisfied},
  'easy'  => {'color': Colors.blue[300],   'icon': Icons.sentiment_satisfied_alt_outlined},
  _       => {'color': Colors.grey,        'icon': Icons.help_outline},
};
