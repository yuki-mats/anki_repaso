import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_edit_page.dart';
import 'app_colors.dart';
import 'learning_analytics_page.dart';
import 'lobby_page.dart';
import 'my_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart'; // AnswerPageのインポートを追加
import 'question_list_page.dart'; // QuestionListPageのインポートを追加

class QuestionSetsListPage extends StatefulWidget {
  final DocumentSnapshot folder;

  QuestionSetsListPage({Key? key, required this.folder}) : super(key: key);

  @override
  _QuestionSetListPageState createState() => _QuestionSetListPageState();
}

class _QuestionSetListPageState extends State<QuestionSetsListPage> {

  void navigateToQuestionSetAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderRef: folder.reference),
      ),
    );
  }

  void navigateToLearningAnalyticsPage(BuildContext context, DocumentSnapshot questionSet) async {
    try {
      // デバッグ用: QuestionSet ID を確認
      print("QuestionSet ID: ${questionSet.id}");

      // questions コレクションから指定の questionSetRef に関連する質問を取得
      QuerySnapshot questionSnapshot = await FirebaseFirestore.instance
          .collection("questions")
          .where("questionSetRef", isEqualTo: questionSet.reference)
          .get();

      // リファレンスをリスト化
      List<DocumentReference> questionRefs = questionSnapshot.docs.map((doc) => doc.reference).toList();

      // デバッグ用
      print("QuestionRefs: ${questionRefs.map((ref) => ref.id).toList()}");

      // 質問がない場合はエラーメッセージを表示
      if (questionRefs.isEmpty) {
        print("No questions found for the selected question set.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("この問題セットには質問がありません。")),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LearningAnalyticsPage(questionRefs: questionRefs),
        ),
      );
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  void navigateToQuestionSetsEditPage(BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetEditPage(
          initialQuestionSetName: questionSet['name'],
          folderId: folder.id,
          questionSetId: questionSet.id,
        ),
      ),
    );

    if (result == true) {
      setState(() {}); // 更新後、画面を再構築
    }
  }

  void navigateToQuestionAddPage(BuildContext context, DocumentReference folderRef ,DocumentReference questionSetRef) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionAddPage(
          folderRef: folderRef,
          questionSetRef: questionSetRef,
        ),
      ),
    );
  }

  void navigateToAnswerPage(BuildContext context, DocumentReference folderRef, DocumentReference questionSetRef, String questionSetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerPage(
          folderRef: folderRef,
          questionSetRef: questionSetRef,
          questionSetName: questionSetName,
        ),
      ),
    );
  }

  void navigateToQuestionListPage(BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionListPage(
          folder: folder,
          questionSet: questionSet,
          questionSetName: questionSet['name'],
        ),
      ),
    );
  }

  void showQuestionSetOptionsModal(BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 360,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.blue200, // 背景色
                      borderRadius: BorderRadius.circular(100), // 角を丸くする
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      size: 22, // アイコンのサイズを調整
                      color: AppColors.blue500,
                    ),
                  ),
                  title: Text(
                    questionSet['name'],
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis, // 長すぎる場合は省略記号を表示
                    maxLines: 2, // 最大1行に制限
                  ),
                ),
                SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.gray100), // 区切り線
                SizedBox(height: 16),
                Container(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100, // 背景色
                        borderRadius: BorderRadius.circular(100), // 角を丸くする
                      ),
                      child: const Icon(
                          Icons.list,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('問題の一覧', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionListPage(context, folder, questionSet);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100, // 背景色
                        borderRadius: BorderRadius.circular(100), // 角を丸くする
                      ),
                      child: const Icon(
                          Icons.add,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionAddPage(context, folder.reference, questionSet.reference);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100, // 背景色
                        borderRadius: BorderRadius.circular(100), // 角を丸くする
                      ),
                      child: const Icon(Icons.show_chart_rounded,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('グラフの確認', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToLearningAnalyticsPage(context, questionSet);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100, // 背景色
                        borderRadius: BorderRadius.circular(100), // 角を丸くする
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 22,
                          color: AppColors.gray600),
                    ),
                    title: const Text('名前を変更', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(context, folder, questionSet);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder['name']),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.gray100,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("questionSets")
              .where("folderRef", isEqualTo: FirebaseFirestore.instance.collection("folders").doc(widget.folder.id)) // 現在のフォルダIDを使用してフィルタリング
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('エラーが発生しました'));
            }
            final questionSets = snapshot.data?.docs ?? [];
            return ListView.builder(
              itemCount: questionSets.length,
              itemBuilder: (context, index) {
                final questionSet = questionSets[index];
                final questionCount = questionSet['questionCount'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 24.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          navigateToAnswerPage(context, widget.folder.reference, questionSet.reference, questionSet['name']);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              color: Colors.white,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.blue200, // 背景色
                                      borderRadius: BorderRadius.circular(100), // 角を丸くする
                                      border: Border.all(
                                        color: AppColors.blue200, // 枠線の色
                                        width: 1.0, // 枠線の太さ
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.quiz_rounded,
                                      size: 22, // アイコンのサイズを調整
                                      color: AppColors.blue500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 48,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            questionSet['name'],
                                            style: const TextStyle(fontSize: 16),
                                            overflow: TextOverflow.ellipsis, // 長すぎる場合は省略記号を表示
                                            maxLines: 1, // 最大1行に制限
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.filter_none,
                                            size: 16,
                                            color: AppColors.blue400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${questionCount.toString()}', // 動的に問題数を表示
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    showQuestionSetOptionsModal(context, widget.folder, questionSet);
                                  },
                                  icon: const Icon(Icons.more_horiz_outlined, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
        floatingActionButton:Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0), // Positioned above the BottomNavigationBar
          child: FloatingActionButton(
            onPressed: () {
              navigateToQuestionSetAddPage(context, widget.folder);
            },
            backgroundColor: AppColors.blue500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Ensure it is a circle
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}