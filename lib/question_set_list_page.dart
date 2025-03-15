import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/question_set_add_page.dart';
import 'package:repaso/question_set_edit_page.dart';
import 'package:repaso/services/question_count.dart';
import 'package:repaso/widgets/list_page_widgets/memory_level_progress_bar.dart';
import 'package:repaso/widgets/answer_page_widgets/question_rate_display.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import 'utils/app_colors.dart';
import 'learning_analytics_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart';
import 'question_list_page.dart';

class QuestionSetsListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final String folderPermission; // 追加

  QuestionSetsListPage({
    Key? key,
    required this.folder,
    required this.folderPermission, // 追加
  }) : super(key: key);

  @override
  _QuestionSetListPageState createState() => _QuestionSetListPageState();
}

class _QuestionSetListPageState extends State<QuestionSetsListPage> {

  void navigateToQuestionSetAddPage(BuildContext context, DocumentSnapshot folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionSetsAddPage(folderId: folder.id),
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


  void navigateToQuestionAddPage(
      BuildContext context,
      DocumentReference folderRef,
      DocumentReference questionSetRef
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionAddPage(
          folderId: folderRef.id,
          questionSetId: questionSetRef.id,
        ),
      ),
    );

    print('QuestionAddPageからの戻り値: $result');

    if (result == true) {
      Future.microtask(() {
        if (mounted) {
          print('FolderListPageへ true を渡します');
          try {
            Navigator.of(context, rootNavigator: true).pop(true);
          } catch (e) {
            print('Navigator.pop() 実行時にエラー発生: $e');
          }
        } else {
          print('ウィジェットが破棄されているため、Navigator.pop を呼び出しません');
        }
      });
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


  void navigateToAnswerPage(BuildContext context, DocumentReference folderRef, DocumentReference questionSetRef, String questionSetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerPage(
          // folderId と questionSetId を渡す
          folderId: folderRef.id,
          questionSetId: questionSetRef.id,
          questionSetName: questionSetName,
        ),
      ),
    );
  }
  void showQuestionSetOptionsModal(BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) async {
    // FolderListPageから渡されたfolderPermissionを利用
    bool isViewer = widget.folderPermission == 'viewer';

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
            height: 420,
            child: Column(
              children: [
                ListTile(
                  leading: const RoundedIconBox(
                    icon: Icons.quiz_outlined,
                    iconColor: AppColors.blue600,
                    backgroundColor: AppColors.blue100,
                    borderRadius: 8,
                    size: 34,
                    iconSize: 22,
                  ),
                  title: Text(
                    questionSet['name'],
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.list, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('問題の一覧', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToQuestionListPage(context, folder, questionSet);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.show_chart_rounded, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('グラフの確認', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToLearningAnalyticsPage(context, questionSet);
                  },
                ),
                const SizedBox(height: 8),
                // 問題の追加（編集権限がない場合は無効化）
                Tooltip(
                  message: isViewer ? '編集権限がありません。' : '',
                  child: ListTile(
                    enabled: !isViewer,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.add, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () {
                      Navigator.of(context).pop();
                      navigateToQuestionAddPage(context, folder.reference, questionSet.reference);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 名前を変更（編集権限がない場合は無効化）
                Tooltip(
                  message: isViewer ? '編集権限がありません。' : '',
                  child: ListTile(
                    enabled: !isViewer,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('名前を変更', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(context, folder, questionSet);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 削除する（削除権限がない場合は無効化）
                Tooltip(
                  message: isViewer ? '削除権限がありません。' : '',
                  child: ListTile(
                    enabled: !isViewer,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.delete_outline, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('削除する', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () async {
                      Navigator.of(context).pop();
                      // 確認ダイアログを表示
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                          title: const Text(
                            '本当に削除しますか？',
                            style: TextStyle(color: Colors.black87, fontSize: 18),
                          ),
                          content: const Text('問題集の配下の問題も削除されます。この操作は取り消しできません。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('戻る', style: TextStyle(color: Colors.black87)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('削除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true) {
                        FirebaseFirestore firestore = FirebaseFirestore.instance;
                        WriteBatch batch = firestore.batch();
                        final deletedAt = FieldValue.serverTimestamp();

                        // 質問集自体をソフトデリート
                        batch.update(questionSet.reference, {
                          'isDeleted': true,
                          'deletedAt': deletedAt,
                        });

                        // 配下の質問を取得してソフトデリート
                        QuerySnapshot questionSnapshot = await firestore
                            .collection("questions")
                            .where("questionSetRef", isEqualTo: questionSet.reference)
                            .get();
                        for (var question in questionSnapshot.docs) {
                          batch.update(question.reference, {
                            'isDeleted': true,
                            'deletedAt': deletedAt,
                          });
                        }

                        // バッチ更新を実行
                        await batch.commit();

                        // 上位フォルダの質問数を再計算して更新
                        await updateQuestionCounts(folder.id, questionSet.id);

                        // folderSetUserStats の memoryLevels から対象の質問エントリーを削除
                        Map<String, dynamic> deletionMap = {};
                        for (var question in questionSnapshot.docs) {
                          deletionMap["memoryLevels.${question.id}"] = FieldValue.delete();
                        }
                        if (deletionMap.isNotEmpty) {
                          await widget.folder.reference
                              .collection('folderSetUserStats')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .update(deletionMap);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('問題集と配下の問題が削除されました。')),
                        );
                        Navigator.of(context).pop(true);
                      }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context, true);  // ★ ここでtrueを返す
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.gray100, height: 1.0),
        ),
      ),
      body: Container(
        color: AppColors.gray50,
        padding: const EdgeInsets.only(top: 16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("questionSets")
              .where("folderId", isEqualTo: widget.folder.id)
              .where("isDeleted", isEqualTo: false)  // 追加: 削除フラグがfalseのもののみ表示
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('エラーが発生しました'));
            }
            final questionSets = snapshot.data?.docs ?? [];
            if (questionSets.isEmpty) {
              // ここで「表示する問題集がありません。」というメッセージを表示する
              return const Center(
                child: Text(
                  "問題集がありません。\n\n早速、右下をタップし作成しよう！",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              );
            }
            // 名前の昇順でソート
            questionSets.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aName = aData['name'] ?? '';
              final bName = bData['name'] ?? '';
              return aName.toString().compareTo(bName.toString());
            });
            return ListView.builder(
              itemCount: questionSets.length,
              itemBuilder: (context, index) {
                final questionSet = questionSets[index];
                final questionSetData = questionSet.data() as Map<String, dynamic>? ?? {};
                final questionCount = questionSetData['questionCount'] ?? 0;

                return StreamBuilder<DocumentSnapshot>(
                  stream: questionSet.reference
                      .collection('questionSetUserStats')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, userStatsSnapshot) {
                    Map<String, int> memoryLevels = {
                      'again': 0,
                      'hard': 0,
                      'good': 0,
                      'easy': 0,
                    };

                    if (userStatsSnapshot.hasData && userStatsSnapshot.data!.exists) {
                      final userStatsData = userStatsSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final memoryData = userStatsData['memoryLevels'] as Map<String, dynamic>? ?? {};
                      memoryData.forEach((key, value) {
                        if (memoryLevels.containsKey(value)) {
                          memoryLevels[value] = memoryLevels[value]! + 1;
                        }
                      });
                    }

                    // **正答数の計算 (hard, good, easy の合計)**
                    final correctAnswers = (memoryLevels['easy'] ?? 0) +
                        (memoryLevels['good'] ?? 0) +
                        (memoryLevels['hard'] ?? 0);

                    final totalAnswers = (memoryLevels['easy'] ?? 0) +
                        (memoryLevels['good'] ?? 0) +
                        (memoryLevels['hard'] ?? 0) +
                        (memoryLevels['again'] ?? 0);

                    // **未回答数の計算**
                    final unanswered = (questionCount > correctAnswers)
                        ? (questionCount - correctAnswers)
                        : 0;

                    // 未回答を memoryLevels に追加
                    memoryLevels['unanswered'] = unanswered;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: InkWell(
                          onTap: () {
                            navigateToAnswerPage(context, widget.folder.reference, questionSet.reference, questionSetData['name']);
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0, left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    RoundedIconBox(
                                      icon: Icons.quiz_outlined, // アイコン
                                      iconColor: widget.folder['isPublic'] ? Colors.orange : AppColors.blue600, // 公開フォルダならオレンジ
                                      backgroundColor: widget.folder['isPublic'] ? Colors.orange.withOpacity(0.2) : AppColors.blue100, // 公開フォルダなら薄いオレンジ背景
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        questionSetData['name'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                                      onPressed: () {
                                        showQuestionSetOptionsModal(context, widget.folder, questionSet);
                                      },
                                    ),
                                  ],
                                ),
                                QuestionRateDisplay(
                                  top: correctAnswers,
                                  bottom: totalAnswers,
                                  memoryLevels: memoryLevels,
                                  count: questionCount,
                                  countSuffix: ' 問',
                                ),
                                const SizedBox(height: 2),
                                // **メモリーレベルのプログレスバー**
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: MemoryLevelProgressBar(memoryValues: memoryLevels),
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
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            navigateToQuestionSetAddPage(context, widget.folder);
          },
          backgroundColor: AppColors.blue500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
