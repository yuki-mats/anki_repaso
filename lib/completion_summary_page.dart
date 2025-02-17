import 'dart:math';
import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';

class CompletionSummaryPage extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final VoidCallback onViewResults;
  final VoidCallback onExit;

  // ProgressBar 用に必要なデータ
  final List<Map<String, dynamic>> answerResults;

  const CompletionSummaryPage({
    Key? key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.onViewResults,
    required this.onExit,
    required this.answerResults,
  }) : super(key: key);

  // メモリレベルごとの色設定
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

  // プログレスバーの色を計算
  List<Color> _getProgressColors() {
    // 質問数が0なら灰色のみ
    if (totalQuestions == 0) {
      return [Colors.grey[300]!];
    }

    // メモリレベルをカウント
    final Map<String, int> memoryLevelCounts = {
      'easy': 0,
      'good': 0,
      'hard': 0,
      'again': 0,
      'unanswered': totalQuestions - answerResults.length,
    };

    for (var result in answerResults) {
      final level = result['memoryLevel'] ?? 'unanswered';
      if (memoryLevelCounts.containsKey(level)) {
        memoryLevelCounts[level] = memoryLevelCounts[level]! + 1;
      } else {
        memoryLevelCounts[level] = 1;
      }
    }

    // 表示順を定義
    List<String> levelOrder = ['again', 'hard', 'good', 'easy', 'unanswered'];

    // レベルごとのカラーをまとめて生成
    List<Color> colors = [];
    for (String level in levelOrder) {
      final count = memoryLevelCounts[level] ?? 0;
      if (count > 0) {
        colors.addAll(List.filled(count, _getMemoryLevelColor(level)));
      }
    }
    return colors;
  }

  String getRandomMessageByAccuracy(double accuracy) {
    final random = Random();
    if (accuracy <= 20) {
      return [
        '少しずつ慣れていこう！最初は誰でも難しいけれど、続けることが大切だよ。',
        'ここからスタート！次はもっと良い結果を目指そう。',
        '少しずつ覚えていけば大丈夫！今は基礎を固める時期だよ。',
        '最初は誰でも難しいもの。一緒に乗り越えよう！',
        '学び始めたばかりだね。次のチャレンジで成長を感じよう！',
      ][random.nextInt(5)];
    } else if (accuracy <= 40) {
      return [
        '良いスタートだね！次はもっとできるようになるよ。',
        '少しずつ結果が見えてきたね。この調子で進めよう！',
        '良い兆しだね！次はもっとできるようになるよ。',
        '成長が感じられるよ！次も挑戦してみよう。',
        'ここまで来たね！次の一歩でさらに自信がつくよ。',
      ][random.nextInt(5)];
    } else if (accuracy <= 60) {
      return [
        '半分以上覚えられているよ！あと少しで目標に近づくね。',
        'ここまでの成果を大事にして、次も頑張ろう！',
        '順調だね！さらに高みを目指していこう。',
        '素晴らしい進歩だよ！この勢いを大切にしよう。',
        'もう少しで目標達成だね！次も期待してるよ！',
      ][random.nextInt(5)];
    } else if (accuracy <= 80) {
      return [
        'かなり良い成績だね！この調子で進めよう！',
        'あと少しで完璧だよ！自信を持って進んでいこう。',
        '素晴らしい成果だね！もっと上を目指せるよ。',
        '努力の成果がしっかり出ているね！',
        'この調子ならすぐに完璧に近づけるよ！',
      ][random.nextInt(5)];
    } else if (accuracy < 100) {
      return [
        'ほぼ完璧！あと少しで完璧な結果が見えてくるね。',
        '素晴らしい！あとほんの少しで満点だよ。',
        'ここまで来たのはすごいね！最終調整をしてみよう。',
        '自信を持っていいよ！次は全問正解を目指そう。',
        '惜しい！でもここまでの成果は十分誇れるよ！',
      ][random.nextInt(5)];
    } else {
      return [
        '完璧！本当におめでとう！',
        '全問正解！努力の成果が実ったね！',
        '素晴らしい結果だよ！自分を褒めてあげよう！',
        '最高のパフォーマンス！次もこの調子で！',
        '完璧な結果！君ならやれると思ってたよ！',
      ][random.nextInt(5)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = (correctAnswers / totalQuestions * 100).toStringAsFixed(1);
    final accuracyValue = correctAnswers / totalQuestions * 100;
    final message = getRandomMessageByAccuracy(accuracyValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '結果',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      // AnswerPage と同じように Column を使って、上部にプログレスバーを表示
      body: Column(
        children: [
          // 上部のプログレスバー
          Row(
            children: _getProgressColors().map((color) {
              return Expanded(
                child: Container(
                  height: 10,
                  color: color,
                ),
              );
            }).toList(),
          ),

          // 残りのコンテンツをまとめてスクロール可能にする
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16.0, left: 32.0, right: 32.0),
              child: Column(
                children: [
                  // 正答率の円グラフ表示
                  Padding(
                    padding: const EdgeInsets.only(top:48.0),
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
                                  ? AppColors.blue400
                                  : AppColors.blue400,
                              strokeWidth: 10,
                            ),
                          ),
                          Text(
                            accuracy.replaceAll(RegExp(r'\.0'), '') + '%',
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
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ボタンエリア
                  Column(
                    children: [
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
          ),
        ],
      ),
    );
  }
}
