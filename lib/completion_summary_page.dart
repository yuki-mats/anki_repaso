import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class CompletionSummaryPage extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final VoidCallback onRetryAll;
  final VoidCallback onRetryIncorrect;
  final VoidCallback onViewResults;
  final VoidCallback onExit;

  const CompletionSummaryPage({
    Key? key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.onRetryAll,
    required this.onRetryIncorrect,
    required this.onViewResults,
    required this.onExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accuracy = (correctAnswers / totalQuestions * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '結果',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top:80.0, left: 32.0, right: 32.0),
        child: Column(
          children: [
            // 正答率の円グラフ表示エリア
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: correctAnswers / totalQuestions,
                        backgroundColor: Colors.grey.shade300,
                        color: correctAnswers == totalQuestions
                            ? Colors.green
                            : Colors.red,
                        strokeWidth: 10,
                      ),
                    ),
                    Text(
                      '$accuracy%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              '大丈夫、次に向けて頑張ろう',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 56),
            // ボタンエリア
            Column(
              children: [
                ElevatedButton(
                  onPressed: onRetryAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'もう一度（全て）',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetryIncorrect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'もう一度（間違いのみ）',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onViewResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '結果を確認',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: AppColors.blue600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '終了',
                    style: TextStyle(fontSize: 16, color: AppColors.blue600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
