import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_list_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/question_set_edit_page.dart';
import 'package:repaso/services/question_count.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import '../utils/app_colors.dart';
import '../widgets/list_page_widgets/options_modal_sheet.dart';
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

  Future<void> navigateToQuestionAddPage(
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
    if (result == true && mounted) {
      Navigator.of(context, rootNavigator: true).pop(true);
    }
  }

  Future<void> navigateToQuestionSetsEditPage(
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

  Future<void> _confirmAndDeleteQuestionSet(
      BuildContext context, DocumentSnapshot questionSet) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
        title: const Text(
          '本当に削除しますか？',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        content: const Text(
            '問題集の配下の問題も削除されます。この操作は取り消しできません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('戻る', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final deletedAt = FieldValue.serverTimestamp();

      batch.update(questionSet.reference, {
        'isDeleted': true,
        'deletedAt': deletedAt,
      });

      final qsnap = await firestore
          .collection("questions")
          .where("questionSetRef", isEqualTo: questionSet.reference)
          .get();
      for (var q in qsnap.docs) {
        batch.update(q.reference, {
          'isDeleted': true,
          'deletedAt': deletedAt,
        });
      }
      await batch.commit();
      await updateQuestionCounts(widget.folder.id, questionSet.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題集と配下の問題が削除されました。')),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  void showQuestionSetOptionsModal(
      BuildContext context, DocumentSnapshot folder, DocumentSnapshot questionSet) {
    final isViewer = widget.folderPermission == 'viewer';

    showOptionsModal(
      context: context,
      headerWidget: ListTile(
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
      items: [
        OptionItem(
          icon: Icons.list,
          iconColor: AppColors.gray600,
          iconBgColor: AppColors.gray100,
          title: '問題の一覧',
          onTap: () => navigateToQuestionListPage(context, folder, questionSet),
        ),
        OptionItem(
          icon: Icons.show_chart_rounded,
          iconColor: AppColors.gray600,
          iconBgColor: AppColors.gray100,
          title: 'グラフの確認',
          onTap: () => navigateToLearningAnalyticsPage(context, questionSet),
        ),
        OptionItem(
          icon: Icons.add,
          iconColor: AppColors.gray600,
          iconBgColor: AppColors.gray100,
          title: '問題の追加',
          enabled: !isViewer,
          onTap: () =>
              navigateToQuestionAddPage(context, folder.reference, questionSet.reference),
        ),
        OptionItem(
          icon: Icons.edit_outlined,
          iconColor: AppColors.gray600,
          iconBgColor: AppColors.gray100,
          title: '名前を変更',
          enabled: !isViewer,
          onTap: () => navigateToQuestionSetsEditPage(context, folder, questionSet),
        ),
        OptionItem(
          icon: Icons.delete_outline,
          iconColor: AppColors.gray600,
          iconBgColor: AppColors.gray100,
          title: '削除する',
          enabled: !isViewer,
          onTap: () => _confirmAndDeleteQuestionSet(context, questionSet),
        ),
      ],
      height: 420,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder['name']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, true),
        ),
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
                final aName = (a.data() as Map<String, dynamic>)['name'] ?? '';
                final bName = (b.data() as Map<String, dynamic>)['name'] ?? '';
                return aName.compareTo(bName);
              });
              return ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 80),
                itemCount: questionSets.length,
                itemBuilder: (context, index) {
                  final qs = questionSets[index];
                  final data = qs.data() as Map<String, dynamic>;
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
                        correct = base['easy']! + base['good']! + base['hard']!;
                        total = correct + base['again']!;
                      }
                      base['unanswered'] =
                      questionCount > correct ? questionCount - correct : 0;

                      return ReusableProgressCard(
                        iconData: Icons.quiz_outlined,
                        iconColor: AppColors.blue500,
                        iconBgColor: AppColors.blue100,
                        title: data['name'] ?? '未設定',
                        isVerified: widget.folder['isPublic'] == true,
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
                            showQuestionSetOptionsModal(context, widget.folder, qs),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
