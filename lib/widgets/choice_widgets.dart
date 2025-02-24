import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
