import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_edit_page.dart';
import 'app_colors.dart';
import 'lobby_page.dart';
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
  void navigateToQuestionSetsAddPage(BuildContext context, String folderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderId: folderId),
      ),
    );
  }


  // 設定モーダルを表示するメソッドを追加
  void showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.logout,
                        size: 36,
                        color: AppColors.gray800
                        ),
                    title: const Text('ログアウト', style: TextStyle(fontSize: 18)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LobbyPage()),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline, size: 36),
                    title: const Text('アカウントの削除', style: TextStyle(fontSize: 18)),
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

  void navigateToQuestionAddPage(BuildContext context, String folderId, String questionSetId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionAddPage(
          folderId: folderId,
          questionSetId: questionSetId,
        ),
      ),
    );
  }

  void navigateToAnswerPage(BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerPage(
          folderId: folder.id,
          questionSetId: questionSet.id,
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
              padding: const EdgeInsets.fromLTRB(46, 36, 24, 12),
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 36, color: AppColors.blue500),
                  const SizedBox(width: 16),
                  Text(
                    questionSet['name'],
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.gray100), // 区切り線
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.add,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionAddPage(context, folder.id, questionSet.id);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題集名の編集', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(context, folder, questionSet);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 24),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(Icons.show_chart_rounded,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('定着度を確認', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(context, folder, questionSet);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0.0, 24, 48),
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: const Icon(
                        Icons.list,
                        size: 36,
                        color: AppColors.gray800),
                    title: const Text('問題の一覧', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionListPage(context, folder, questionSet);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("questionSets")
              .where("folder", isEqualTo: FirebaseFirestore.instance.collection("folders").doc(widget.folder.id)) // 現在のフォルダIDを使用してフィルタリング
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
                final totalQuestions = questionSet['totalQuestions'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          navigateToAnswerPage(context, widget.folder, questionSet);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16.0, right: 16.0),
                                  child: SizedBox(
                                    width: 40,
                                    child: Icon(
                                      Icons.layers_rounded,
                                      size: 40,
                                      color: AppColors.blue500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 52,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            questionSet['name'],
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.insert_drive_file_rounded,
                                            size: 16,
                                            color: AppColors.blue400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${totalQuestions.toString()}', // 動的に問題数を表示
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
                      const SizedBox(height: 16.0), // タイル間のスペース
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            navigateToQuestionSetsAddPage(context, widget.folder.id);
          } else if (index == 3) {
            showSettingsModal(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open, size: 42),
            label: 'ライブラリ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 42),
            label: '追加',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.not_started_outlined, size: 42),
            label: '開始',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, size: 42),
            label: 'アカウント',
          ),
        ],
      ),
    );
  }
}