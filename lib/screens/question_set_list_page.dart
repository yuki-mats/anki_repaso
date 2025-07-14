import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_list_page.dart';
import 'package:repaso/screens/question_set_add_page.dart';
import 'package:repaso/screens/question_set_edit_page.dart';
import 'package:repaso/services/question_count.dart';
import 'package:repaso/widgets/list_page_widgets/rounded_icon_box.dart';
import '../utils/app_colors.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import '../widgets/list_page_widgets/reusable_progress_card.dart';
import 'learning_analytics_page.dart';
import 'question_add_page.dart';
import 'answer_page.dart';

class QuestionSetsListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final String folderPermission;

  const QuestionSetsListPage({
    Key? key,
    required this.folder,
    required this.folderPermission,
  }) : super(key: key);

  @override
  _QuestionSetListPageState createState() => _QuestionSetListPageState();
}

class _QuestionSetListPageState extends State<QuestionSetsListPage> {
  /* ───────── 既存ナビゲーション系メソッド（省略なしで掲載） ───────── */
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

  /* ────────── オプションモーダル ────────── */
/* ────────── オプションモーダル ────────── */
  void showQuestionSetOptionsModal(
      BuildContext context,
      DocumentSnapshot folder,
      DocumentSnapshot questionSet,
      ) {
    /* ───── 権限判定 ───── */
    final bool isViewer =
        widget.folderPermission != 'owner' && widget.folderPermission != 'editor';
    final bool canEdit = !isViewer;

    /* ───── カラーをカードと同じロジックで決定 ───── */
    final Color iconColor   = Colors.white;
    final Color iconBgColor = canEdit ? Colors.blue[700]!   : Colors.grey[500]!;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft : Radius.circular(12.0),
          topRight: Radius.circular(12.0),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: isViewer ? 340 : 480, // 1 行ぶん高さ拡張
            child: Column(
              children: [
                /* ─ ドラッグハンドル ─ */
                Padding(
                  padding: const EdgeInsets.only(top: 0, bottom: 16),
                  child: Center(
                    child: Container(
                      width : 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                /* ─ タイトル ─ */
                ListTile(
                  leading: RoundedIconBox(
                    icon            : Icons.dehaze_rounded,
                    iconColor       : iconColor,
                    backgroundColor : iconBgColor,
                    borderRadius    : 8,
                    size            : 34,
                    iconSize        : 22,
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

                /* ───── 共通メニュー ───── */
                ListTile(
                  leading: Container(
                    width : 40,
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
                    width : 40,
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
                /* ★★★ 追加: 記憶度をクリア ★★★ */
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(Icons.restart_alt,
                        size: 22, color: AppColors.gray600),
                  ),
                  title: const Text('学習履歴をクリア', style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    Navigator.of(context).pop(); // まずモーダルを閉じる
                    /* ─── 以降は既存ロジック（省略なし） ─── */
                    final res = await DeleteConfirmationDialog.show(
                      context,
                      title       : '学習履歴をクリア',
                      bulletPoints: const ['問題集の記憶度', '問題集の正答率'],
                      description : 'この問題集の記憶度が初期化されます。\n上位フォルダの正答率・記憶度にも反映されます。',
                      confirmText : 'クリア',
                      cancelText  : '戻る',
                      showCheckbox: false,
                    );

                    if (res != null && res.confirmed) {
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;

                        final firestore = FirebaseFirestore.instance;

                        /* ---------- クリア対象の questionId を取得 ---------- */
                        final qSnap = await firestore
                            .collection('questions')
                            .where('questionSetRef', isEqualTo: questionSet.reference)
                            .get();

                        /* ---------- バッチ書き込み準備 ---------- */
                        final batch = firestore.batch();

                        // ① questionSetUserStats の記憶度 & 正答率系のみリセット
                        final qsStatRef = questionSet.reference
                            .collection('questionSetUserStats')
                            .doc(uid);
                        batch.set(
                          qsStatRef,
                          {
                            'memoryLevels'     : <String, String>{},
                            'attemptCount'     : 0,
                            'correctCount'     : 0,
                            'incorrectCount'   : 0,
                            'memoryLevelStats' : {
                              'again': 0, 'hard': 0, 'good': 0, 'easy': 0,
                            },
                            'memoryLevelRatios': {
                              'again': 0, 'hard': 0, 'good': 0, 'easy': 0,
                            },
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );

                        // ② folderSetUserStats の該当 questionId キーを削除
                        final folderStatRef = firestore
                            .collection('folders')
                            .doc(folder.id)
                            .collection('folderSetUserStats')
                            .doc(uid);

                        batch.set(
                          folderStatRef,
                          {
                            'memoryLevels': <String, String>{},
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );

                        final Map<String, dynamic> folderUpdate = {
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        for (final q in qSnap.docs) {
                          folderUpdate['memoryLevels.${q.id}'] = FieldValue.delete();
                        }
                        if (folderUpdate.length > 1) batch.update(folderStatRef, folderUpdate);

                        await batch.commit();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('記憶度をクリアしました。')),
                          );
                        }
                      } catch (e) {
                        debugPrint('Clear memoryLevels error: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('エラーが発生しました')),
                          );
                        }
                      }
                    }
                  },
                ),

                /* ───── 編集権限ありのみ表示 ───── */
                if (!isViewer) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Container(
                      width : 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.add, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('問題の追加', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionAddPage(
                        context,
                        widget.folder.reference,
                        questionSet.reference,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Container(
                      width : 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child:
                      const Icon(Icons.edit_outlined, size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('名前を変更', style: TextStyle(fontSize: 16)),
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToQuestionSetsEditPage(context, folder, questionSet);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Container(
                      width : 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 22, color: AppColors.gray600),
                    ),
                    title: const Text('削除する', style: TextStyle(fontSize: 16)),
                    onTap: () async {
                      /* ---------- 既存削除ロジック（省略せず） ---------- */
                      Navigator.of(context).pop();

                      final res = await DeleteConfirmationDialog.show(
                        context,
                        title       : '問題集を削除',
                        bulletPoints: const ['問題集本体', '配下の問題'],
                        description : '問題集の配下の問題も削除されます。この操作は取り消しできません。',
                        confirmText : '削除',
                        cancelText  : '戻る',
                        showCheckbox: false,
                        confirmColor: Colors.redAccent,
                      );

                      if (res != null && res.confirmed) {
                        final firestore = FirebaseFirestore.instance;
                        final batch     = firestore.batch();
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

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('問題集と配下の問題が削除されました。')),
                        );
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }


  /* ────────── build ────────── */
  @override
  Widget build(BuildContext context) {
    final bool canEditFolder =
        widget.folderPermission == 'owner' || widget.folderPermission == 'editor';
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
          child: Text(widget.folder['name'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              )),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.gray100),
        ),
      ),
      body: Container(
        color: Colors.white,
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
                padding: const EdgeInsets.only(top: 16, bottom: 140),
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
                        final m = statSnap.data!['memoryLevels'] as Map<String, dynamic>? ?? {};
                        for (var v in m.values) {
                          if (base.containsKey(v)) base[v] = base[v]! + 1;
                        }
                        correct = base['easy']! + base['good']! + base['hard']!;
                        total = correct + base['again']!;
                      }
                      base['unanswered'] = questionCount > correct ? questionCount - correct : 0;

                      return ReusableProgressCard(
                        iconData: Icons.dehaze_rounded,
                        iconColor: Colors.white,
                        iconBgColor: Colors.blue[700]!,
                        title: data['name'] ?? '未設定',
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
                        selectionMode: false,
                        cardId: qs.id,
                        selectedId: null,
                        onSelected: null,
                        hasPermission: widget.folderPermission == 'owner' ||
                            widget.folderPermission == 'editor',
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: canEditFolder
          ? Padding(
        padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
        child: FloatingActionButton(
          onPressed: () => navigateToQuestionSetAddPage(context, widget.folder),
          backgroundColor: AppColors.blue500,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
