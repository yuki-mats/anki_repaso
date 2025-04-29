import 'package:flutter/material.dart';
import 'package:repaso/utils/app_colors.dart';
// ↓ Firestore と FirebaseAuth を使うために必要
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewAnswersPage extends StatelessWidget {
  final List<Map<String, dynamic>> results;

  const ReviewAnswersPage({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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

            // questionId を持っている前提で進めます
            final questionId = result['questionId'] as String;

            return GestureDetector(
              onTap: () {
                // タップ時の処理（例: 詳細ページへ飛ぶなど）
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
                          size: 24,
                        ),
                        const SizedBox(width: 8),
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      questionText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    "答",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      correctAnswer,
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ここから修正部分：StreamBuilder でFirestoreを監視
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('questions')
                              .doc(questionId)
                              .collection('questionUserStats')
                              .doc(user?.uid) // user が null の可能性もある
                              .snapshots(),
                          builder: (context, snapshot) {
                            // ドキュメント未取得・エラー時は一旦「ブックマークなし」で表示
                            if (!snapshot.hasData || snapshot.hasError) {
                              return IconButton(
                                icon: const Icon(Icons.bookmark_border),
                                color: Colors.grey,
                                onPressed: () async {
                                  if (user == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('ブックマークにはログインが必要です。'),
                                      ),
                                    );
                                    return;
                                  }
                                  // ログインしていてドキュメント未取得の場合は、
                                  // とりあえずブックマーク登録( isFlagged=true )する例
                                  await FirebaseFirestore.instance
                                      .collection('questions')
                                      .doc(questionId)
                                      .collection('questionUserStats')
                                      .doc(user.uid)
                                      .set({
                                    'userRef': FirebaseFirestore.instance.collection('users').doc(user.uid),
                                    'isFlagged': true,
                                  }, SetOptions(merge: true));
                                },
                              );
                            }

                            // データが取得できた場合
                            final data = snapshot.data!.data() as Map<String, dynamic>?;

                            // isFlagged がなければ false とする
                            final bool isFlagged = data?['isFlagged'] ?? false;

                            return IconButton(
                              icon: Icon(
                                // フラグが true なら Icons.bookmark、false なら Icons.bookmark_border
                                isFlagged ? Icons.bookmark : Icons.bookmark_border,
                              ),
                              // アイコンの色も true/false で変える例
                              color: isFlagged ? Colors.grey : Colors.grey,
                              onPressed: () async {
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ブックマークにはログインが必要です。'),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  // クリックすると、isFlagged をトグル(反転)する例
                                  await FirebaseFirestore.instance
                                      .collection('questions')
                                      .doc(questionId)
                                      .collection('questionUserStats')
                                      .doc(user.uid)
                                      .set({
                                    'userRef': FirebaseFirestore.instance.collection('users').doc(user.uid),
                                    'isFlagged': !isFlagged,
                                  }, SetOptions(merge: true));

                                  // 成功時のメッセージはご自由に
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isFlagged ? 'ブックマーク解除しました。' : 'ブックマークしました。',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  // エラー処理
                                  print('Error toggling bookmark: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ブックマーク更新に失敗しました。'),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        // ここまで修正
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
