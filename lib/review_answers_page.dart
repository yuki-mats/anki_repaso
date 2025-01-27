import 'package:flutter/material.dart';
import 'package:repaso/app_colors.dart';

class ReviewAnswersPage extends StatelessWidget {
  final List<Map<String, dynamic>> results;

  const ReviewAnswersPage({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回答結果'),
      ),
      body: Container(
        color: AppColors.gray50,
        child: ListView.builder(
          itemCount: results.length,
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          itemBuilder: (context, index) {
            final result = results[index];
            final isCorrect = result['isCorrect'] as bool;
            final questionText = result['questionText'] as String;
            final correctAnswer = result['correctAnswer'] as String;

            return GestureDetector(
              onTap: () {
                // タップ時の処理を追加（例: 詳細ページへの遷移）
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // マル・バツアイコン
                        Icon(
                          isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        // 質問と答えの内容
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "問",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      questionText,
                                      style: const TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    "答",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      correctAnswer,
                                      style: TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                            icon: const Icon(Icons.bookmark_border),
                            onPressed: () {
                              // お気に入りの処理
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
