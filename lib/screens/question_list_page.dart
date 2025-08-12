// lib/screens/question_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repaso/screens/question_add_page.dart';
import '../services/memory_level_sync.dart'; // そのまま
import '../services/move_questions_with_memory.dart';
import '../services/question_count_update.dart';
import '../utils/app_colors.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import 'question_edit_page.dart';

// ★ 追加：ピッカー
import '../widgets/list_page_widgets/question_set_move_picker.dart';

class QuestionListPage extends StatefulWidget {
  final DocumentSnapshot folder;
  final DocumentSnapshot questionSet;
  final String questionSetName;

  const QuestionListPage({
    Key? key,
    required this.folder,
    required this.questionSet,
    required this.questionSetName,
  }) : super(key: key);

  @override
  _QuestionListPageState createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {
  /* ───────── 複数選択（最小リビルド） ───────── */
  final ValueNotifier<bool> _selectionMode = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> _selectedIds =
  ValueNotifier<Set<String>>(<String>{});
  List<String> _cachedQuestionIds = const [];

  // ── 記憶度カラー（これまでの配色に合わせる）
  Color _memoryLevelBg(String level) {
    switch (level) {
      case 'again':
        return Colors.red[500]!;
      case 'hard':
        return Colors.orangeAccent;
      case 'good':
        return Colors.green[500]!;
      case 'easy':
        return Colors.blue;
      case '未学習':
      default:
        return AppColors.gray400;
    }
  }

  Widget _memoryLevelBadge(String level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _memoryLevelBg(level),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _enterSelectionMode() {
    if (!_selectionMode.value) {
      _selectionMode.value = true;
      _selectedIds.value = <String>{};
    }
  }

  void _cancelSelection() {
    _selectionMode.value = false;
    _selectedIds.value = <String>{};
  }

  void _toggleSelection(String qid) {
    final next = Set<String>.from(_selectedIds.value);
    next.contains(qid) ? next.remove(qid) : next.add(qid);
    _selectedIds.value = next;
  }

  void _toggleSelectAll() {
    if (_cachedQuestionIds.isEmpty) return;
    final all = _cachedQuestionIds.toSet();
    if (_selectedIds.value.length == all.length) {
      _selectedIds.value = <String>{};
    } else {
      _selectedIds.value = all;
      _selectionMode.value = true;
    }
  }

  Future<void> _toggleFlag(DocumentSnapshot question) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseFirestore.instance
          .collection('questions')
          .doc(question.id)
          .collection('questionUserStats')
          .doc(user.uid);

      final snap = await ref.get();
      final current =
          (snap.data() as Map<String, dynamic>?)?['isFlagged'] == true;

      await ref.set({
        'isFlagged': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('toggleFlag error: $e');
    }
  }

  /* ───────── 「フォルダ/問題集へ移動」実装 ───────── */
  Future<void> _bulkMoveSelected() async {
    final ids = _selectedIds.value.toList();
    if (!mounted || ids.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('移動する問題を選択してください')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 移動先ピッカー（フォルダは選択不可・問題集のみ単一選択）
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetMovePickerPage(userId: uid),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return; // キャンセル

    final toQuestionSetId = result['questionSetId'] as String;
    final toFolderId      = result['folderId'] as String;

    if (toQuestionSetId == widget.questionSet.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('同じ問題集が選択されています')));
      return;
    }

    try {
      await moveQuestionsWithMemoryForUser(
        userId: uid,
        questionIds: ids,
        fromFolderId: widget.folder.id,
        fromQuestionSetId: widget.questionSet.id,
        toFolderId: toFolderId,
        toQuestionSetId: toQuestionSetId,
      );

      if (!mounted) return;
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} 件を移動し、記憶度を引き継ぎました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('移動に失敗しました: $e')));
    }
  }


  /// 選択された複数の問題を、指定の QuestionSet へ移動。
  /// - questions.* の questionSetId / questionSetRef / folderId を更新
  /// - ユーザーの memoryLevels を旧→新へ移管（questionSet / folder）
  /// - 件数を再計算（旧/新）
  Future<void> _moveQuestionsToSet({
    required List<String> questionIds,
    required String destFolderId,
    required String destQuestionSetId,
    required DocumentReference destQuestionSetRef,
  }) async {
    final fs = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final String srcFolderId = widget.folder.id;
    final String srcQuestionSetId = widget.questionSet.id;
    final DocumentReference srcQuestionSetRef = widget.questionSet.reference;

    // 1) 質問ドキュメントを一括更新
    final batch = fs.batch();
    final now = FieldValue.serverTimestamp();
    for (final qid in questionIds) {
      final qRef = fs.collection('questions').doc(qid);
      batch.update(qRef, {
        'questionSetId': destQuestionSetId,
        'questionSetRef': destQuestionSetRef,
        'folderId': destFolderId,
        'updatedAt': now,
      });
    }
    await batch.commit();

    // 2) memoryLevels の移管（ユーザー単位）
    //    - 各 questionUserStats/{uid}.memoryLevel を取得し、
    //      旧 questionSetUserStats/{uid}.memoryLevels.<qid> を delete、
    //      新 questionSetUserStats/{uid}.memoryLevels.<qid> に set
    //    - folder 側（folderSetUserStats/{uid}）も同様
    final srcQsUser = srcQuestionSetRef
        .collection('questionSetUserStats')
        .doc(uid);
    final destQsUser = destQuestionSetRef
        .collection('questionSetUserStats')
        .doc(uid);

    final srcFolderUser = fs
        .collection('folders')
        .doc(srcFolderId)
        .collection('folderSetUserStats')
        .doc(uid);
    final destFolderUser = fs
        .collection('folders')
        .doc(destFolderId)
        .collection('folderSetUserStats')
        .doc(uid);

    // 事前に存在を保証
    await Future.wait([
      srcQsUser.set({'updatedAt': now}, SetOptions(merge: true)),
      destQsUser.set({'updatedAt': now}, SetOptions(merge: true)),
      srcFolderUser.set({'updatedAt': now}, SetOptions(merge: true)),
      destFolderUser.set({'updatedAt': now}, SetOptions(merge: true)),
    ]);

    final Map<String, dynamic> qsAdd = {};
    final Map<String, dynamic> qsDel = {};
    final Map<String, dynamic> folderAdd = {};
    final Map<String, dynamic> folderDel = {};

    for (final qid in questionIds) {
      // 各問題のユーザーステータスから memoryLevel を取得
      final qUserDoc = await fs
          .collection('questions')
          .doc(qid)
          .collection('questionUserStats')
          .doc(uid)
          .get();

      final memLevel =
      (qUserDoc.data()?['memoryLevel'] as String?)?.trim();

      // 旧側で削除
      qsDel['memoryLevels.$qid'] = FieldValue.delete();
      folderDel['memoryLevels.$qid'] = FieldValue.delete();

      if (memLevel != null && memLevel.isNotEmpty) {
        // 新側へ追加
        qsAdd['memoryLevels.$qid'] = memLevel;
        folderAdd['memoryLevels.$qid'] = memLevel;
      }
    }

    // 更新をまとめて実行
    final memBatch = fs.batch();
    if (qsDel.isNotEmpty) memBatch.update(srcQsUser, qsDel);
    if (folderDel.isNotEmpty) memBatch.update(srcFolderUser, folderDel);
    if (qsAdd.isNotEmpty) memBatch.set(destQsUser, qsAdd, SetOptions(merge: true));
    if (folderAdd.isNotEmpty) {
      memBatch.set(destFolderUser, folderAdd, SetOptions(merge: true));
    }
    await memBatch.commit();

    // 3) 件数の再計算（旧 → 新）
    await questionCountsUpdate(srcFolderId, srcQuestionSetId);
    await questionCountsUpdate(destFolderId, destQuestionSetId);
  }

  Future<void> _bulkClearSelected() async {
    final ids = _selectedIds.value.toList();
    if (!mounted || ids.isEmpty) return;

    final result = await DeleteConfirmationDialog.show(
      context,
      title: '学習履歴をクリア',
      description: '選択中の${ids.length} 問の学習履歴（記憶度）がクリアされます。\nこの操作は取り消しできません。',
      bulletPoints: ['選択中の${ids.length} 問'],
      confirmText: 'クリア',
      cancelText: 'キャンセル',
      confirmColor: Colors.redAccent,
    );
    if (result == null || !result.confirmed) return;

    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final qsUserDoc = widget.questionSet.reference
          .collection('questionSetUserStats')
          .doc(uid);
      final folderUserDoc =
      widget.folder.reference.collection('folderSetUserStats').doc(uid);

      await Future.wait([
        qsUserDoc.set({'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true)),
        folderUserDoc.set({'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true)),
      ]);

      final Map<String, dynamic> mapDeletes = {
        for (final qid in ids) 'memoryLevels.$qid': FieldValue.delete(),
      };

      await Future.wait([
        qsUserDoc.update(mapDeletes),
        folderUserDoc.update(mapDeletes),
      ]);

      final batch = fs.batch();
      for (final qid in ids) {
        final qUserDoc = fs
            .collection('questions')
            .doc(qid)
            .collection('questionUserStats')
            .doc(uid);
        batch.set(
            qUserDoc,
            {
              'memoryLevel': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} 件の学習履歴をクリアしました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('学習履歴のクリアに失敗しました: $e')),
      );
    }
  }

  Future<void> _bulkDeleteSelected() async {
    final ids = _selectedIds.value.toList();
    if (!mounted || ids.isEmpty) return;

    final result = await DeleteConfirmationDialog.show(
      context,
      title: '問題を削除',
      description: '選択中の${ids.length} 問が削除されます。\nこの操作は取り消しできません。',
      bulletPoints: ['選択中の${ids.length} 問'],
      confirmText: '削除',
      cancelText: 'キャンセル',
      confirmColor: Colors.redAccent,
    );
    if (result == null || !result.confirmed) return;

    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final batch = fs.batch();
      for (final qid in ids) {
        batch.update(
          fs.collection('questions').doc(qid),
          {
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedById': uid,
          },
        );
      }
      await batch.commit();

      await removeMemoryLevelsOnQuestionDeleteForUser(
        userId: uid,
        folderId: widget.folder.id,
        questionSetId: widget.questionSet.id,
        questionIds: ids,
      );

      await questionCountsUpdate(widget.folder.id, widget.questionSet.id);

      if (!mounted) return;
      _cancelSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} 件の問題を削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _selectionMode.dispose();
    _selectedIds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.questionSetName)),
        body: const Center(child: Text('ログインしていません')),
      );
    }

    final permissionDocRef =
    widget.folder.reference.collection('permissions').doc(user.uid);

    return FutureBuilder<DocumentSnapshot>(
      future: permissionDocRef.get(),
      builder: (context, permSnap) {
        if (permSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.questionSetName)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (permSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.questionSetName)),
            body: const Center(child: Text('権限情報の取得でエラーが発生しました')),
          );
        }

        final permData =
            permSnap.data?.data() as Map<String, dynamic>? ?? {};
        final role = permData['role'] ?? 'viewer';
        final bool isViewer = (role == 'viewer');

        return Scaffold(
          appBar: AppBar(
            title: ValueListenableBuilder<bool>(
              valueListenable: _selectionMode,
              builder: (_, sel, __) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: sel
                      ? ValueListenableBuilder<Set<String>>(
                    valueListenable: _selectedIds,
                    builder: (_, ids, __) => Text(
                      '${ids.length} 件選択中',
                      key: const ValueKey('sel'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  )
                      : Text(widget.questionSetName,
                      key: const ValueKey('title')),
                );
              },
            ),
            leading: ValueListenableBuilder<bool>(
              valueListenable: _selectionMode,
              builder: (_, sel, __) {
                return sel
                    ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _cancelSelection,
                )
                    : const BackButton();
              },
            ),
            actions: [
              if (!isViewer)
                ValueListenableBuilder<bool>(
                  valueListenable: _selectionMode,
                  builder: (_, sel, __) {
                    if (!sel) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon: const Icon(Icons.check_box_outlined, size: 24),
                          tooltip: '複数選択',
                          onPressed: _enterSelectionMode,
                        ),
                      );
                    } else {
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.select_all, size: 24),
                            tooltip: 'すべて選択/解除',
                            onPressed: _toggleSelectAll,
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz, size: 24),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                ),
                                builder: (_) => _QuestionBulkActionSheet(
                                  selectedCount: _selectedIds.value.length,
                                  onMoveTap: () {
                                    Navigator.pop(context);
                                    _bulkMoveSelected(); // ← ここで実装済み
                                  },
                                  onClearTap: () {
                                    Navigator.pop(context);
                                    _bulkClearSelected();
                                  },
                                  onDeleteTap: () {
                                    Navigator.pop(context);
                                    _bulkDeleteSelected();
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      );
                    }
                  },
                ),
            ],
          ),
          backgroundColor: AppColors.gray50,
          floatingActionButton: !isViewer
              ? ValueListenableBuilder<bool>(
            valueListenable: _selectionMode,
            builder: (_, sel, __) {
              if (sel) return const SizedBox.shrink();
              return Padding(
                padding:
                const EdgeInsets.only(bottom: 8, right: 16),
                child: FloatingActionButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuestionAddPage(
                          folderId: widget.folder.id,
                          questionSetId: widget.questionSet.id,
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 40),
                ),
              );
            },
          )
              : null,
          floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('questions')
                .where('questionSetId', isEqualTo: widget.questionSet.id)
                .where('isDeleted', isEqualTo: false)
                .snapshots(),
            builder: (context, qsSnap) {
              if (qsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (qsSnap.hasError) {
                return const Center(child: Text('エラーが発生しました'));
              }

              final questions = qsSnap.data?.docs ?? [];
              _cachedQuestionIds =
                  questions.map((e) => e.id).toList(growable: false);

              if (questions.isEmpty) {
                return const Center(child: Text('問題がありません'));
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: widget.questionSet.reference
                    .collection('questionSetUserStats')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
                builder: (context, ustatSnap) {
                  final memoryLevels =
                      (ustatSnap.data?.data() as Map<String, dynamic>?)?[
                      'memoryLevels'] as Map<String, dynamic>? ??
                          const <String, dynamic>{};

                  return ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      final qdata =
                          (question.data() as Map<String, dynamic>?) ?? {};
                      final questionText =
                          (qdata['questionText'] as String?) ?? '問題なし';
                      final correctAnswer =
                          (qdata['correctChoiceText'] as String?) ?? '正解なし';

                      final memoryLevelText =
                          (memoryLevels[question.id] as String?) ?? '未学習';

                      return _buildQuestionItem(
                        context: context,
                        question: question,
                        questionText: questionText,
                        correctAnswer: correctAnswer,
                        isViewer: isViewer,
                        memoryLevelText: memoryLevelText,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /* ───────── 各行（UI据え置き） ───────── */
  Widget _buildQuestionItem({
    required BuildContext context,
    required DocumentSnapshot question,
    required String questionText,
    required String correctAnswer,
    required bool isViewer,
    required String memoryLevelText,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _selectionMode,
            builder: (_, sel, __) {
              if (!sel) return const SizedBox(width: 0, height: 0);
              return ValueListenableBuilder<Set<String>>(
                valueListenable: _selectedIds,
                builder: (_, ids, __) {
                  final selected = ids.contains(question.id);
                  return GestureDetector(
                    onTap: () => _toggleSelection(question.id),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 12, top: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.blue[700] : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected
                              ? Colors.blue[700]!
                              : AppColors.gray300,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                          size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectionMode.value) {
                  _toggleSelection(question.id);
                } else if (!isViewer) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          QuestionEditPage(question: question),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 16.0, top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuestionAnswerRow(
                        label: '問',
                        text: questionText,
                        labelTextColor: Colors.white,
                        labelBgColor: Colors.blue[800]!,
                      ),
                      const SizedBox(height: 16),
                      _buildQuestionAnswerRow(
                        label: '答',
                        text: correctAnswer,
                        labelTextColor: Colors.blue[800]!,
                        labelBgColor: Colors.blue[100]!,
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('questions')
                            .doc(question.id)
                            .collection('questionUserStats')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots(),
                        builder: (context, statsSnap) {
                          final stats = statsSnap.data?.data()
                          as Map<String, dynamic>? ??
                              const {};
                          final isFlagged = stats['isFlagged'] == true;

                          final int attemptCount =
                              (stats['attemptCount'] as num?)?.toInt() ?? 0;
                          final int correctCount =
                              (stats['correctCount'] as num?)?.toInt() ?? 0;
                          final String correctRateText = attemptCount > 0
                              ? '${((correctCount * 100) / attemptCount).toStringAsFixed(0)}%'
                              : '0%';

                          return Row(
                            children: [
                              Text(
                                correctRateText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray400,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  isFlagged
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  color: AppColors.gray400,
                                ),
                                onPressed: () async =>
                                    _toggleFlag(question),
                              ),
                              const SizedBox(width: 8),
                              _memoryLevelBadge(memoryLevelText),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionAnswerRow({
    required String label,
    required String text,
    required Color labelTextColor,
    required Color labelBgColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          alignment: Alignment.center,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: labelBgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: labelTextColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/* 既存の一括アクションシート（変更なし：onMoveTap が実装先） */
class _QuestionBulkActionSheet extends StatelessWidget {
  const _QuestionBulkActionSheet({
    Key? key,
    required this.selectedCount,
    required this.onMoveTap,
    required this.onClearTap,
    required this.onDeleteTap,
  }) : super(key: key);

  final int selectedCount;
  final VoidCallback onMoveTap;
  final VoidCallback onClearTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_box_outlined,
                    color: Colors.white, size: 22),
              ),
              title: Text('$selectedCount 件選択中',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.gray100),
            const SizedBox(height: 16),
            _item(Icons.drive_file_move_outline, 'フォルダ/問題集へ移動', onMoveTap),
            const SizedBox(height: 8),
            _item(Icons.restart_alt, '学習履歴をクリア', onClearTap),
            const SizedBox(height: 8),
            _item(Icons.delete_outline, '削除する', onDeleteTap),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, size: 22, color: AppColors.gray600),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}
