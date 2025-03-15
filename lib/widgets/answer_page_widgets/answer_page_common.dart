import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommonQuestionFooter extends StatelessWidget {
  final double? correctRate;
  final String? hintText;
  final String? explanationText;
  final String? footerButtonType;
  final bool flashCardHasBeenRevealed;
  final bool isOfficialQuestion;
  final bool isFlagged;
  final VoidCallback? onShowHintDialog;
  final VoidCallback? onShowExplanationDialog;
  final VoidCallback? onToggleFlag;
  final VoidCallback? onMemoPressed;

  const CommonQuestionFooter({
    Key? key,
    this.correctRate,
    this.hintText,
    this.explanationText,
    this.footerButtonType,
    required this.flashCardHasBeenRevealed,
    required this.isFlagged,
    required this.isOfficialQuestion,
    this.onShowHintDialog,
    this.onShowExplanationDialog,
    this.onToggleFlag,
    this.onMemoPressed,
  }) : super(key: key);

  /// 丸いボタンを作成するヘルパーメソッド
  Widget _buildRoundedIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white, // 背景を白に設定
      ),
      child: IconButton(
        icon: Icon(icon, size: 22, color: Colors.grey),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ヒントや解説の有無のチェック
    final hasHint = hintText?.trim().isNotEmpty ?? false;
    final hasExplanation = explanationText?.trim().isNotEmpty ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const Text(
              '正答率',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              '${(correctRate != null) ? correctRate!.toStringAsFixed(0) : '-'}%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヒントアイコン（ヒントテキストが存在する場合）
            if (hasHint)
              _buildRoundedIconButton(
                icon: Icons.lightbulb_outline,
                onPressed: onShowHintDialog,
              ),

            // 解説アイコン（footerButtonTypeが非nullまたはフラッシュカードの答えが開示されているかつ解説テキストが存在する場合）
            if ((footerButtonType != null || flashCardHasBeenRevealed) && hasExplanation)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: _buildRoundedIconButton(
                  icon: Icons.description_outlined,
                  onPressed: onShowExplanationDialog,
                ),
              ),

            const SizedBox(width: 8),
            if (isOfficialQuestion)
            // メモアイコン
            _buildRoundedIconButton(
              icon: Icons.edit_note_outlined,
              onPressed: onMemoPressed,
            ),

            const SizedBox(width: 8),

            // フラグ（ブックマーク）アイコン
            _buildRoundedIconButton(
              icon: isFlagged ? Icons.bookmark : Icons.bookmark_outline,
              onPressed: onToggleFlag,
            ),
          ],
        ),
      ],
    );
  }
}

/// True/False 選択ウィジェット
class TrueFalseWidget extends StatelessWidget {
  final String correctChoiceText;
  final String selectedChoiceText;
  final void Function(BuildContext, String) handleAnswerSelection;

  const TrueFalseWidget({
    Key? key,
    required this.correctChoiceText,
    required this.selectedChoiceText,
    required this.handleAnswerSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trueLabel = "正しい";
    final falseLabel = "間違い";
    final choices = [trueLabel, falseLabel];
    final isAnswerSelected = selectedChoiceText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...choices.map((choice) {
          final isSelected = selectedChoiceText == choice;
          final isCorrect = correctChoiceText == choice;
          final isIncorrect = isSelected && !isCorrect;

          return GestureDetector(
            onTap: () {
              // 追加：タップ時にフィードバックを発生させる
              HapticFeedback.selectionClick();
              if (!isAnswerSelected) {
                handleAnswerSelection(context, choice);
              }
            },
            child: Container(
              height: 48,
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
                    child: Text(choice,
                        style: const TextStyle(fontSize: 12, color: Colors.black)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

/// 単一選択ウィジェット
class SingleChoiceWidget extends StatelessWidget {
  final List<String> choices;
  final String correctChoiceText;
  final String? selectedAnswer;
  final void Function(BuildContext, String) handleAnswerSelection;

  const SingleChoiceWidget({
    Key? key,
    required this.choices,
    required this.correctChoiceText,
    required this.selectedAnswer,
    required this.handleAnswerSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAnswerSelected = selectedAnswer != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: choices.map((choice) {
        final isSelected = selectedAnswer == choice;
        final isCorrect = choice == correctChoiceText;
        final isIncorrect = isSelected && !isCorrect;

        return GestureDetector(
          onTap: () {
            // 追加：タップ時にフィードバックを発生させる
            HapticFeedback.selectionClick();
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
                  child: Text(choice,
                      style: const TextStyle(fontSize: 12, color: Colors.black)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// フラッシュカードウィジェット
class FlashCardWidget extends StatelessWidget {
  final bool isAnswerShown;
  final VoidCallback onToggle;

  const FlashCardWidget({
    Key? key,
    required this.isAnswerShown,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 追加：タップ時にフィードバックを発生させる
        HapticFeedback.selectionClick();
        onToggle();
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26, width: 1.0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isAnswerShown ? '問題に戻る' : '答えを見る',
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// フッターボタンを表示するウィジェット
Widget buildFooterButtons({
  required String questionType,
  required bool? isAnswerCorrect,
  required bool flashCardAnswerShown, // フラッシュカードの場合、回答済みかどうか
  required VoidCallback onMemoryLevelSelected,
  required VoidCallback onNextPressed,
  required Function(String) saveAnswer,
}) {
  if (questionType == 'flash_card') {
    // flash_cardの場合、回答が表示されていなければボタンを非表示
    if (!flashCardAnswerShown) {
      return SizedBox.shrink();
    }
    // 回答が表示されている場合は、常に ['Again', 'Hard', 'Good', 'Easy'] のボタンを表示
    final levels = ['Again', 'Hard', 'Good', 'Easy'];
    return _buildMemoryLevelButtons(levels, onMemoryLevelSelected, saveAnswer);
  } else if (isAnswerCorrect == null) {
    return SizedBox.shrink(); // まだ回答していない場合は非表示
  } else if (isAnswerCorrect == true) {
    final levels = ['Hard', 'Good', 'Easy'];
    return _buildMemoryLevelButtons(levels, onMemoryLevelSelected, saveAnswer);
  } else {
    return _buildNextButton(onNextPressed);
  }
}


/// メモリレベル選択ボタンの共通ウィジェット
Widget _buildMemoryLevelButtons(
    List<String> levels,
    VoidCallback onMemoryLevelSelected,
    Function(String) saveAnswer,
    ) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.green, width: 4.0)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: levels.map((displayText) {
        final memoryLevel = displayText.toLowerCase();
        final buttonData = _getButtonStyle(memoryLevel);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () {
                saveAnswer(memoryLevel);
                onMemoryLevelSelected();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonData['color'],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero, // 内部の余白をなくす
                minimumSize: Size.zero, // 必要に応じて最小サイズをなくす
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // タップ領域を最小化
              ),
              child: Padding(
                padding: const EdgeInsets.only(top:3.0, bottom: 3.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(buttonData['icon'], color: Colors.white, size: 18),
                    const SizedBox(height: 4),
                    Text(displayText, style: const TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

/// Next ボタンの共通ウィジェット
Widget _buildNextButton(VoidCallback onNextPressed) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.redAccent, width: 4.0)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
    child: ElevatedButton(
      onPressed: onNextPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('次へ', style: TextStyle(fontSize: 18, color: Colors.white)),
    ),
  );
}

/// メモリレベルボタンのスタイルを取得するヘルパー関数
Map<String, dynamic> _getButtonStyle(String level) {
  switch (level) {
    case 'again':
      return {'color': Colors.red[300], 'icon': Icons.refresh};
    case 'hard':
      return {'color': Colors.orange[300], 'icon': Icons.sentiment_dissatisfied_outlined};
    case 'good':
      return {'color': Colors.green[300], 'icon': Icons.sentiment_satisfied};
    case 'easy':
      return {'color': Colors.blue[300], 'icon': Icons.sentiment_satisfied_alt_outlined};
    default:
      return {'color': Colors.grey, 'icon': Icons.help_outline};
  }
}



