import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_list_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/question_set_edit_page.dart';
import 'package:repaso/services/question_count.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import '../utils/app_colors.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import 'learning_analytics_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart';

class QuestionSetsListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final String folderPermission;

  QuestionSetsListPage({
    Key? key,
    required this.folder,
    required this.folderPermission,
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
      print("QuestionSet ID: ${questionSet.id}");
      QuerySnapshot questionSnapshot = await FirebaseFirestore.instance
          .collection("questions")
          .where("questionSetRef", isEqualTo: questionSet.reference)
          .get();

      List<DocumentReference> questionRefs =
      questionSnapshot.docs.map((doc) => doc.reference).toList();

      if (questionRefs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("この問題セットには質問がありません。")),
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

  void navigateToQuestionListPage(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
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
      BuildContext context, DocumentReference folderRef, DocumentReference questionSetRef) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionAddPage(
          folderId: folderRef.id,
          questionSetId: questionSetRef.id,
        ),
      ),
    );

    if (result == true) {
      Future.microtask(() {
        if (mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop(true);
          } catch (e) {
            print('Navigator.pop() error: $e');
          }
        }
      });
    }
  }

  void navigateToQuestionSetsEditPage(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) async {
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

    if (result == true) setState(() {});
  }

  void navigateToAnswerPage(BuildContext context, DocumentReference folderRef,
      DocumentReference questionSetRef, String questionSetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswerPage(
          folderId: folderRef.id,
          questionSetId: questionSetRef.id,
          questionSetName: questionSetName,
        ),
      ),
    );
  }

  void showQuestionSetOptionsModal(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
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
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
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
                    child:
                    const Icon(Icons.list, size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('問題の一覧', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToQuestionListPage(
                        context, widget.folder, questionSet);
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
                    child: const Icon(Icons.show_chart_rounded,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('グラフの確認', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.of(context).pop();
                    navigateToLearningAnalyticsPage(context, questionSet);
                  },
                ),
                const SizedBox(height: 8),
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
                      child:
                      const Icon(Icons.add, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () {
                      Navigator.of(context).pop();
                      navigateToQuestionAddPage(
                          context, widget.folder.reference, questionSet.reference);
                    },
                  ),
                ),
                const SizedBox(height: 8),
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
                      child: const Icon(Icons.edit_outlined,
                          size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('名前を変更', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(
                          context, widget.folder, questionSet);
                    },
                  ),
                ),
                const SizedBox(height: 8),
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
                      child: const Icon(Icons.delete_outline,
                          size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('削除する', style: TextStyle(fontSize: 16)),
                    onTap: isViewer
                        ? null
                        : () async {
                      Navigator.of(context).pop();
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                          title: const Text(
                            '本当に削除しますか？',
                            style: TextStyle(
                                color: Colors.black87, fontSize: 18),
                          ),
                          content: const Text(
                              '問題集の配下の問題も削除されます。この操作は取り消しできません。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('戻る',
                                  style:
                                  TextStyle(color: Colors.black87)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('削除',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true) {
                        final firestore = FirebaseFirestore.instance;
                        final batch = firestore.batch();
                        final deletedAt = FieldValue.serverTimestamp();

                        batch.update(questionSet.reference, {
                          'isDeleted': true,
                          'deletedAt': deletedAt,
                        });

                        final qsnap = await firestore
                            .collection("questions")
                            .where("questionSetRef",
                            isEqualTo: questionSet.reference)
                            .get();
                        for (var q in qsnap.docs) {
                          batch.update(q.reference, {
                            'isDeleted': true,
                            'deletedAt': deletedAt,
                          });
                        }
                        await batch.commit();
                        await updateQuestionCounts(
                            widget.folder.id, questionSet.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  '問題集と配下の問題が削除されました。')),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, true),
        ),
        leadingWidth: 40,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(widget.folder['name']),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.gray100),
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: MediaQuery.removePadding(
          removeTop: true,
          context: context,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("questionSets")
                .where("folderId", isEqualTo: widget.folder.id)
                .where("isDeleted", isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Center(child: Text('エラーが発生しました'));
              }
              final questionSets = snap.data!.docs;
              if (questionSets.isEmpty) {
                return const Center(
                  child: Text(
                    "問題集がありません。\n\n早速、右下をタップし作成しよう！",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              questionSets.sort((a, b) {
                final aName =
                    (a.data() as Map<String, dynamic>)['name'] ?? '';
                final bName =
                    (b.data() as Map<String, dynamic>)['name'] ?? '';
                return aName.compareTo(bName);
              });
              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 80),
                itemCount: questionSets.length,
                itemBuilder: (context, index) {
                  final qs = questionSets[index];
                  final data =
                  qs.data() as Map<String, dynamic>;
                  final questionCount = data['questionCount'] ?? 0;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: qs.reference
                        .collection('questionSetUserStats')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (ctx, statSnap) {
                      final base = {
                        'again': 0,
                        'hard': 0,
                        'good': 0,
                        'easy': 0
                      };
                      int correct = 0, total = 0;
                      if (statSnap.hasData && statSnap.data!.exists) {
                        final m = statSnap.data!['memoryLevels']
                        as Map<String, dynamic>? ?? {};
                        for (var v in m.values) {
                          if (base.containsKey(v)) base[v] = base[v]! + 1;
                        }
                        correct = base['easy']! +
                            base['good']! +
                            base['hard']!;
                        total = correct + base['again']!;
                      }
                      base['unanswered'] =
                      questionCount > correct
                          ? questionCount - correct
                          : 0;

                      return ReusableProgressCard(
                        iconData: Icons.quiz_outlined,
                        iconColor: AppColors.blue500,
                        iconBgColor: AppColors.blue100,
                        title: data['name'] ?? '未設定',
                        isVerified:
                        widget.folder['isPublic'] == true,
                        memoryLevels: base,
                        correctAnswers: correct,
                        totalAnswers: total,
                        count: questionCount,
                        countSuffix: ' 問',
                        onTap: () => navigateToAnswerPage(
                          context,
                          widget.folder.reference,
                          qs.reference,
                          data['name'] ?? '',
                        ),
                        onMorePressed: () =>
                            showQuestionSetOptionsModal(
                                context, widget.folder, qs),
                        selectionMode  : false,
                        cardId         : qs.id,
                        selectedId     : null,
                        onSelected     : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
        child: FloatingActionButton(
          onPressed: () => navigateToQuestionSetAddPage(context, widget.folder),
          backgroundColor: AppColors.blue500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
