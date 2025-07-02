import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';               // ← PlatformException 用
import 'package:in_app_review/in_app_review.dart';    // ← In-App Review
import 'package:repaso/utils/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repaso/widgets/review_prompt_dialog.dart';

class CompletionSummaryPage extends StatefulWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final VoidCallback onViewResults;
  final VoidCallback onExit;
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

  @override
  _CompletionSummaryPageState createState() => _CompletionSummaryPageState();
}

class _CompletionSummaryPageState extends State<CompletionSummaryPage> {
  final _inAppReview = InAppReview.instance;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowReviewDialog();
    });
  }

  Future<void> _maybeShowReviewDialog() async {
    if (_dialogShown) return;

    // 正答率チェック
    if (widget.totalQuestions == 0) return;
    final rate = widget.correctAnswers / widget.totalQuestions;
    if (rate < 0.90) return;

    // 評価済みチェック
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final hasRated = (userDoc.data()?['hasRated'] ?? false) as bool;
    if (hasRated) return;

    _dialogShown = true;
    await _showReviewDialog();
  }

  Future<void> _showReviewDialog() async {
    if (!mounted) return;
    await ReviewPromptDialog.show(context);
  }

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

  List<Color> _getProgressColors() {
    if (widget.totalQuestions == 0) {
      return [Colors.grey[300]!];
    }
    final counts = {
      'easy': 0,
      'good': 0,
      'hard': 0,
      'again': 0,
      'unanswered': widget.totalQuestions - widget.answerResults.length,
    };
    for (var r in widget.answerResults) {
      final lvl = r['memoryLevel'] ?? 'unanswered';
      if (counts.containsKey(lvl)) {
        counts[lvl] = counts[lvl]! + 1;
      } else {
        counts[lvl] = 1;
      }
    }
    final order = ['again', 'hard', 'good', 'easy', 'unanswered'];
    final colors = <Color>[];
    for (var lvl in order) {
      final c = counts[lvl] ?? 0;
      if (c > 0) colors.addAll(List.filled(c, _getMemoryLevelColor(lvl)));
    }
    return colors;
  }

  String getRandomMessageByAccuracy(double accuracy) {
    final rnd = Random();
    if (accuracy <= 20) {
      return [
        '少しずつ慣れていこう！最初は誰でも難しいけれど、続けることが大切だよ。',
        'ここからスタート！次はもっと良い結果を目指そう。',
        '少しずつ覚えていけば大丈夫！今は基礎を固める時期だよ。',
        '最初は誰でも難しいもの。一緒に乗り越えよう！',
        '学び始めたばかりだね。次のチャレンジで成長を感じよう！',
      ][rnd.nextInt(5)];
    } else if (accuracy <= 40) {
      return [
        '良いスタートだね！次はもっとできるようになるよ。',
        '少しずつ結果が見えてきたね。この調子で進めよう！',
        '良い兆しだね！次はもっとできるようになるよ。',
        '成長が感じられるよ！次も挑戦してみよう。',
        'ここまで来たね！次の一歩でさらに自信がつくよ。',
      ][rnd.nextInt(5)];
    } else if (accuracy <= 60) {
      return [
        '半分以上覚えられているよ！あと少しで目標に近づくね。',
        'ここまでの成果を大事にして、次も頑張ろう！',
        '順調だね！さらに高みを目指していこう。',
        '素晴らしい進歩だよ！この勢いを大切にしよう。',
        'もう少しで目標達成だね！次も期待してるよ！',
      ][rnd.nextInt(5)];
    } else if (accuracy <= 80) {
      return [
        'かなり良い成績だね！この調子で進めよう！',
        'あと少しで完璧だよ！自信を持って進んでいこう。',
        '素晴らしい成果だね！もっと上を目指せるよ。',
        '努力の成果がしっかり出ているね！',
        'この調子ならすぐに完璧に近づけるよ！',
      ][rnd.nextInt(5)];
    } else if (accuracy < 100) {
      return [
        'ほぼ完璧！あと少しで完璧な結果が見えてくるね。',
        '素晴らしい！あとほんの少しで満点だよ。',
        'ここまで来たのはすごいね！最終調整をしてみよう。',
        '自信を持っていいよ！次は全問正解を目指そう。',
        '惜しい！でもここまでの成果は十分誇れるよ！',
      ][rnd.nextInt(5)];
    } else {
      return [
        '完璧！本当におめでとう！',
        '全問正解！努力の成果が実ったね！',
        '素晴らしい結果だよ！自分を褒めてあげよう！',
        '最高のパフォーマンス！次もこの調子で！',
        '完璧な結果！君ならやれると思ってたよ！',
      ][rnd.nextInt(5)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracyValue = widget.correctAnswers / widget.totalQuestions * 100;
    final accuracy = accuracyValue.toStringAsFixed(1);
    final message = getRandomMessageByAccuracy(accuracyValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '結果',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Row(
            children: _getProgressColors()
                .map((c) => Expanded(child: Container(height: 10, color: c)))
                .toList(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, left: 32, right: 32),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 48, bottom: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: widget.correctAnswers /
                                widget.totalQuestions,
                            backgroundColor: Colors.grey.shade300,
                            color: AppColors.blue400,
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
                  Text(
                    message,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: widget.onViewResults,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('結果を確認',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: widget.onExit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(color: AppColors.blue600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('終了',
                        style: TextStyle(fontSize: 16, color: AppColors.blue600)),
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
