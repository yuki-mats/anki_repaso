import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_colors.dart';
import 'question_edit_page.dart';

class QuestionListPage extends StatelessWidget {
  final DocumentSnapshot folder;
  final DocumentSnapshot questionSet;
  final String questionSetName;

  const QuestionListPage({
    Key? key,
    required this.folder,
    required this.questionSet,
    required this.questionSetName,
  }) : super(key: key);

  void testDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      print('Documents Directory: ${directory.path}');
    } catch (e) {
      print('Error retrieving documents directory: $e');
    }
  }

  Future<void> ensureDirectoryExists(String filePath) async {
    final file = File(filePath);
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true); // 必要に応じて親ディレクトリも作成
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(questionSetName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.gray300,
            height: 1.0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                // モーダルを表示
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.0),
                      topRight: Radius.circular(24.0),
                    ),
                  ),
                  builder: (BuildContext context) {
                    return Wrap(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.check_box_outlined, size: 36, color: Colors.blue),
                                title: const Text(
                                  '一括選択',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  // 問題の追加処理
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.upload, size: 36, color: Colors.green),
                                title: const Text(
                                  '問題をインポート',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {

                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 48),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // 背景色
                              borderRadius: BorderRadius.circular(16.0), // カードの角丸
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.download, size: 36, color: Colors.orange),
                                title: const Text(
                                  '問題をエクスポート',
                                  style: TextStyle(fontSize: 18),
                                ),
                                onTap: () {

                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("questions")
              .where('questionSetRef', isEqualTo: questionSet.reference)
              .snapshots(),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }

          final questions = snapshot.data?.docs ?? [];
          if (questions.isEmpty) {
            return const Center(child: Text('問題がありません'));
          }

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              final questionText = question['questionText'] is String
                  ? question['questionText']
                  : '問題なし';

              // correctChoiceTextを取得
              final correctAnswer = question['correctChoiceText'] as String? ?? '正解なし';

              return GestureDetector(
                onTap: () {
                  // QuestionEditPageへ遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestionEditPage(
                        question: question,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3), // Shadow position
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  questionText,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "答",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  correctAnswer, // 正しい答えを表示
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.bookmark_border),
                                onPressed: () {
                                  // お気に入り登録処理
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
          },
      ),
    );
  }
}